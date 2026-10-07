"""Small reviewed name/function glossary; never a health or permission evaluator."""

import hashlib
import json
import re
import unicodedata
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Annotated, Literal, Self

from pydantic import Field, model_validator

from app.community.models import CommunityModel, PublicText, Sha256

MAX_BYTES = 65536
VERSION: Literal["ingredients-2026-10-07.1"] = "ingredients-2026-10-07.1"
SOURCE_URLS = {
    "codex-gsfa-lecithin": "https://www.fao.org/gsfaonline/additives/details.html?id=77",
    "codex-gsfa-citric-acid": "https://www.fao.org/gsfaonline/additives/details.html?id=173",
    "codex-gsfa-xanthan-gum": "https://www.fao.org/gsfaonline/additives/details.html?id=48",
}
ENTRY_CODES = {"lecithin": ["322(i)"], "citric_acid": ["330"], "xanthan_gum": ["415"]}


class GlossarySource(CommunityModel):
    source_id: PublicText
    title: PublicText
    url: Annotated[str, Field(min_length=1, max_length=512)]
    reviewed_on: date
    scope: Literal["name_and_technological_function_only"]


class GlossaryEntry(CommunityModel):
    entry_id: Literal["lecithin", "citric_acid", "xanthan_gum"]
    name_en: PublicText
    name_hi: PublicText
    aliases: list[PublicText] = Field(min_length=1, max_length=16)
    ins_codes: list[PublicText] = Field(min_length=1, max_length=4)
    function_en: PublicText
    function_hi: PublicText
    source_ids: list[PublicText] = Field(min_length=1, max_length=3)


class GlossaryMatch(CommunityModel):
    entry: GlossaryEntry
    matched_text: PublicText
    start: Annotated[int, Field(ge=0, le=16000)]
    end: Annotated[int, Field(ge=1, le=16000)]

    @model_validator(mode="after")
    def valid_span(self) -> Self:
        if self.end - self.start != len(self.matched_text):
            raise ValueError("Glossary match must retain its original span")
        return self


class GlossaryArtifact(CommunityModel):
    sha256: Sha256
    bytes: Annotated[int, Field(ge=1, le=MAX_BYTES)]
    entry_count: Literal[3] = 3


class GlossaryResponse(CommunityModel):
    schema_version: Literal["1"] = "1"
    status: Literal["ready"] = "ready"
    glossary_version: Literal["ingredients-2026-10-07.1"]
    artifact: GlossaryArtifact
    entries: list[GlossaryEntry] = Field(min_length=3, max_length=3)
    sources: list[GlossarySource] = Field(min_length=3, max_length=3)
    warnings: list[PublicText] = Field(
        default_factory=lambda: [
            "small_glossary_not_complete_ingredient_coverage",
            "functions_only_not_health_allergy_or_indian_permission_verdict",
        ],
        max_length=8,
    )


class _Registry(CommunityModel):
    schema_version: Literal["1"]
    glossary_version: Literal["ingredients-2026-10-07.1"]
    reviewed_on: date
    entries: list[GlossaryEntry] = Field(min_length=3, max_length=3)
    sources: list[GlossarySource] = Field(min_length=3, max_length=3)

    @model_validator(mode="after")
    def reviewed_references(self) -> Self:
        sources = {source.source_id: source for source in self.sources}
        if len(sources) != 3 or set(sources) != set(SOURCE_URLS):
            raise ValueError("Glossary sources must be known and unique")
        if self.reviewed_on > datetime.now(UTC).date():
            raise ValueError("Glossary cannot claim a future review")
        for identifier, source in sources.items():
            if source.url != SOURCE_URLS[identifier] or source.reviewed_on != self.reviewed_on:
                raise ValueError("Glossary source reference does not match review")
        if {entry.entry_id for entry in self.entries} != set(ENTRY_CODES):
            raise ValueError("Glossary entries must be known and unique")
        for entry in self.entries:
            if entry.ins_codes != ENTRY_CODES[entry.entry_id]:
                raise ValueError("Glossary does not support that additive subtype")
            if len(set(entry.aliases)) != len(entry.aliases):
                raise ValueError("Glossary aliases must be unique")
            if len(set(entry.source_ids)) != len(entry.source_ids) or any(
                identifier not in sources for identifier in entry.source_ids
            ):
                raise ValueError("Glossary entry needs known unique evidence")
        return self


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("Duplicate glossary field")
        value[key] = item
    return value


def _word_character(character: str) -> bool:
    # Hindi vowel signs and join controls stay attached to their word.
    return (
        character.isalnum()
        or character in {"_", "\u200c", "\u200d"}
        or unicodedata.category(character).startswith("M")
    )


class GlossaryStore:
    """Read the tracked bounded projection once; no remote fetch or fallback."""

    def __init__(self, directory: Path | None = None) -> None:
        path = (directory or Path(__file__).resolve().parent) / "glossary-v1.json"
        for component in (path, *path.parents):
            if component.is_symlink() or component.is_junction():
                raise ValueError("Glossary links are not accepted")
        with path.open("rb") as stream:
            raw = stream.read(MAX_BYTES + 1)
        if not raw or len(raw) > MAX_BYTES:
            raise ValueError("Glossary exceeds its byte budget")
        try:
            decoded = json.loads(raw, object_pairs_hook=_unique_object)
            registry = _Registry.model_validate_json(json.dumps(decoded))
        except (UnicodeError, RecursionError) as error:
            raise ValueError("Invalid glossary projection") from error
        self._entries = tuple(registry.entries)
        self._sources = tuple(registry.sources)
        self.version: Literal["ingredients-2026-10-07.1"] = VERSION
        self.artifact = GlossaryArtifact(sha256=hashlib.sha256(raw).hexdigest(), bytes=len(raw))
        self._patterns = []
        for entry in self._entries:
            aliases = [re.escape(alias) for alias in entry.aliases]
            for code in entry.ins_codes:
                notation = r"322\s*\(\s*i\s*\)" if code == "322(i)" else re.escape(code)
                aliases.append(r"(?:INS|E)\s*[:\-]?\s*" + notation + r"(?!\s*\()")
            expression = r"(?<!\w)(?:" + "|".join(aliases) + r")(?!\w)"
            self._patterns.append((entry, re.compile(expression, re.IGNORECASE)))

    def entries(self) -> list[GlossaryEntry]:
        # Revalidation returns fresh nested lists; callers cannot mutate the store.
        return [GlossaryEntry.model_validate(entry.model_dump()) for entry in self._entries]

    def sources(self) -> list[GlossarySource]:
        return list(self._sources)

    def response(self) -> GlossaryResponse:
        return GlossaryResponse(
            glossary_version=self.version,
            artifact=self.artifact,
            entries=self.entries(),
            sources=self.sources(),
        )

    def match(self, text: str) -> list[GlossaryMatch]:
        if not isinstance(text, str) or len(text) > 16000:
            raise ValueError("Ingredient text exceeds its match budget")
        found = [
            (match.start(), match.end(), match.group(), entry)
            for entry, pattern in self._patterns
            for match in pattern.finditer(text)
            if (match.start() == 0 or not _word_character(text[match.start() - 1]))
            and (match.end() == len(text) or not _word_character(text[match.end()]))
        ]
        found.sort(key=lambda item: (item[0], -item[1]))
        result = []
        previous_end = -1
        for start, end, matched, entry in found:
            if start < previous_end:
                continue
            result.append(
                GlossaryMatch(
                    entry=GlossaryEntry.model_validate(entry.model_dump()),
                    matched_text=matched,
                    start=start,
                    end=end,
                )
            )
            previous_end = end
            if len(result) == 64:
                break
        return result
