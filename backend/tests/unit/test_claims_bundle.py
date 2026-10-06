import json
import shutil
from pathlib import Path

import pytest

from app.claims.bundle import build_knowledge_bundle, verify_knowledge_bundle

KNOWLEDGE = Path(__file__).resolve().parents[3] / "knowledge"


def test_network_free_bundle_copies_only_reviewed_json_and_verifies(tmp_path):
    source = tmp_path / "source"
    shutil.copytree(KNOWLEDGE / "rules", source / "rules")
    shutil.copytree(KNOWLEDGE / "sources/registry", source / "sources/registry")
    (source / "private-scan.txt").write_text("private marker")
    target = tmp_path / "bundle"
    receipt = build_knowledge_bundle(source, target)
    assert len(receipt["files"]) == 2
    assert verify_knowledge_bundle(target) == receipt
    assert not (target / "private-scan.txt").exists()
    assert build_knowledge_bundle(source, target) == receipt


@pytest.mark.parametrize("damage", ["tamper", "missing", "receipt", "oversize"])
def test_packaged_knowledge_damage_fails_closed(tmp_path, damage):
    target = tmp_path / "bundle"
    build_knowledge_bundle(KNOWLEDGE, target)
    rules = target / "rules/claims/reviewed-v1.json"
    if damage == "tamper":
        rules.write_bytes(rules.read_bytes() + b" ")
    elif damage == "missing":
        rules.unlink()
    elif damage == "oversize":
        rules.write_bytes(b" " * 262145)
    else:
        p = target / "receipt.json"
        value = json.loads(p.read_text())
        value["files"][0]["sha256"] = "0" * 64
        p.write_text(json.dumps(value))
    with pytest.raises((ValueError, OSError)):
        verify_knowledge_bundle(target)


def test_builder_preserves_existing_files_and_refuses_linked_output(tmp_path):
    target = tmp_path / "bundle"
    target.mkdir()
    keep = target / "unrelated.txt"
    keep.write_text("operator file")
    with pytest.raises(ValueError):
        build_knowledge_bundle(KNOWLEDGE, target)
    assert keep.read_text() == "operator file"


def test_invalid_source_cannot_replace_valid_bundle(tmp_path):
    target = tmp_path / "bundle"
    receipt = build_knowledge_bundle(KNOWLEDGE, target)
    source = tmp_path / "source"
    source.mkdir()
    with pytest.raises((ValueError, OSError)):
        build_knowledge_bundle(source, target)
    assert verify_knowledge_bundle(target) == receipt
