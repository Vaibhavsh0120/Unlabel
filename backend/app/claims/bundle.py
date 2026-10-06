"""Package only the two bounded reviewed JSON projections, without network access."""

import hashlib
import json
import os
import tempfile
from pathlib import Path
from typing import Literal

from pydantic import Field

from app.claims.knowledge import MAX_KNOWLEDGE_BYTES, KnowledgeStore, _read_json
from app.claims.models import KNOWLEDGE_VERSION
from app.schemas.products import ContractModel

KnowledgePath = Literal["rules/claims/reviewed-v1.json", "sources/registry/fssai-claims-v1.json"]
FILES: tuple[KnowledgePath, ...] = (
    "rules/claims/reviewed-v1.json",
    "sources/registry/fssai-claims-v1.json",
)


class KnowledgeFile(ContractModel):
    path: KnowledgePath
    bytes: int = Field(strict=True, ge=1, le=MAX_KNOWLEDGE_BYTES)
    sha256: str = Field(strict=True, pattern=r"^[0-9a-f]{64}$")


class KnowledgeReceipt(ContractModel):
    schema_version: Literal["1"] = "1"
    knowledge_version: Literal["claims-2026-10-06.1"]
    files: list[KnowledgeFile] = Field(min_length=2, max_length=2)


def _reject_links(path: Path) -> None:
    for component in (path, *path.parents):
        if component.is_symlink() or component.is_junction():
            raise ValueError("Knowledge bundle links are not accepted")


def _bounded_bytes(path: Path) -> bytes:
    _reject_links(path)
    with path.open("rb") as stream:
        raw = stream.read(MAX_KNOWLEDGE_BYTES + 1)
    if not raw or len(raw) > MAX_KNOWLEDGE_BYTES:
        raise ValueError("Knowledge file size is outside its bounds")
    return raw


def verify_knowledge_bundle(directory: Path) -> dict:
    directory = Path(directory).absolute()
    receipt = KnowledgeReceipt.model_validate(_read_json(directory / "receipt.json"))
    if [item.path for item in receipt.files] != list(FILES):
        raise ValueError("Knowledge receipt files differ from the approved projection")
    for item in receipt.files:
        raw = _bounded_bytes(directory / item.path)
        if len(raw) != item.bytes or hashlib.sha256(raw).hexdigest() != item.sha256:
            raise ValueError("Knowledge bundle hash or length does not match its receipt")
    KnowledgeStore(directory)
    return receipt.model_dump(mode="json")


def build_knowledge_bundle(source: Path, output: Path) -> dict:
    source, output = Path(source).absolute(), Path(output).absolute()
    _reject_links(source)
    _reject_links(output)
    KnowledgeStore(source)
    payloads: dict[KnowledgePath, bytes] = {name: _bounded_bytes(source / name) for name in FILES}
    receipt = KnowledgeReceipt(
        knowledge_version=KNOWLEDGE_VERSION,
        files=[
            KnowledgeFile(path=name, bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest())
            for name, raw in payloads.items()
        ],
    ).model_dump(mode="json")
    allowed = {Path(name) for name in (*FILES, "receipt.json")}
    if output.exists():
        if not output.is_dir():
            raise ValueError("Knowledge output must be a directory")
        for path in output.rglob("*"):
            _reject_links(path)
            if not path.is_dir() and path.relative_to(output) not in allowed:
                raise ValueError("Knowledge output contains an unrelated file")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".claims-build-", dir=output.parent) as temporary:
        staging = Path(temporary)
        for name, raw in payloads.items():
            path = staging / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        (staging / "receipt.json").write_text(
            json.dumps(receipt, indent=2) + "\n", encoding="utf-8"
        )
        verify_knowledge_bundle(staging)
        output.mkdir(exist_ok=True)
        for name in (*FILES, "receipt.json"):
            path = output / name
            path.parent.mkdir(parents=True, exist_ok=True)
            _reject_links(path)
            os.replace(staging / name, path)
    return verify_knowledge_bundle(output)
