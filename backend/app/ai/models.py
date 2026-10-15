"""Bounded photo inputs and explicitly unverified machine-read package facts.

Photos and extracted facts are request-local. These models deliberately do not
implement the confirmed-label or public community assertion contracts.
"""

import base64
import binascii
import struct
import unicodedata
import zlib
from typing import Annotated, Literal, Self

from pydantic import BaseModel, BeforeValidator, ConfigDict, Field, model_validator

from app.schemas.nutrition import NutrientName, require_confirmation

MAX_IMAGE_BYTES = 900_000
MAX_IMAGE_BASE64 = ((MAX_IMAGE_BYTES + 2) // 3) * 4
MAX_REQUEST_BYTES = 4 * 1024 * 1024
MAX_IMAGE_PIXELS = 24_000_000
MAX_IMAGE_EDGE = 8192
ImageSlot = Literal["front", "back", "barcode"]


def _text(value: object) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError("Extracted text must be nonempty")
    if any(
        unicodedata.category(character) in {"Cc", "Cs"} and character not in "\n\t"
        for character in value
    ):
        raise ValueError("Extracted text contains invalid characters")
    return value


ShortText = Annotated[str, BeforeValidator(_text), Field(min_length=1, max_length=256)]
LabelText = Annotated[str, BeforeValidator(_text), Field(min_length=1, max_length=16000)]
PrintedText = Annotated[str, BeforeValidator(_text), Field(min_length=1, max_length=512)]
Amount = Annotated[float, Field(strict=True, gt=0, le=100_000, allow_inf_nan=False)]
Value = Annotated[float, Field(strict=True, ge=0, le=1_000_000, allow_inf_nan=False)]
Coordinate = Annotated[float, Field(strict=True, ge=0, le=1, allow_inf_nan=False)]


def _barcode(value: object) -> str:
    if (
        not isinstance(value, str)
        or len(value) not in {8, 12, 13, 14}
        or not value.isascii()
        or not value.isdecimal()
        or set(value) == {"0"}
    ):
        raise ValueError("Extracted barcode must be a supported GTIN")
    total = sum(
        int(digit) * (3 if index % 2 == 0 else 1)
        for index, digit in enumerate(reversed(value[:-1]))
    )
    if (10 - total % 10) % 10 != int(value[-1]):
        raise ValueError("Extracted barcode check digit is invalid")
    return value


def _dimensions(width: int, height: int) -> tuple[int, int]:
    if (
        not 1 <= width <= MAX_IMAGE_EDGE
        or not 1 <= height <= MAX_IMAGE_EDGE
        or width * height > MAX_IMAGE_PIXELS
    ):
        raise ValueError("Photo dimensions exceed the supported bounds")
    return width, height


def _png_dimensions(data: bytes) -> tuple[int, int]:
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Photo does not match its declared image type")
    offset = 8
    dimensions = None
    has_pixels = False
    chunks = 0
    while offset + 12 <= len(data):
        chunks += 1
        if chunks > 2048:
            raise ValueError("Photo contains too many chunks")
        length = struct.unpack_from(">I", data, offset)[0]
        end = offset + 12 + length
        if end > len(data):
            raise ValueError("Photo container is truncated")
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : end - 4]
        if (
            not all(65 <= byte <= 90 or 97 <= byte <= 122 for byte in kind)
            or zlib.crc32(kind + payload) & 0xFFFFFFFF != struct.unpack_from(">I", data, end - 4)[0]
        ):
            raise ValueError("Photo container checksum is invalid")
        if chunks == 1 and kind != b"IHDR":
            raise ValueError("Photo header is missing")
        if kind == b"IHDR":
            if dimensions is not None or length != 13:
                raise ValueError("Photo header is invalid")
            width, height, depth, colour, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            depths = {0: {1, 2, 4, 8, 16}, 2: {8, 16}, 3: {1, 2, 4, 8}, 4: {8, 16}, 6: {8, 16}}
            if (
                depth not in depths.get(colour, set())
                or compression != 0
                or filtering != 0
                or interlace not in {0, 1}
            ):
                raise ValueError("Photo header is unsupported")
            dimensions = _dimensions(width, height)
        elif kind == b"IDAT":
            has_pixels = has_pixels or bool(payload)
        elif kind == b"IEND":
            if length != 0 or end != len(data) or dimensions is None or not has_pixels:
                raise ValueError("Photo container is incomplete")
            return dimensions
        elif not kind[0] & 32 and kind != b"PLTE":
            raise ValueError("Photo contains an unsupported critical chunk")
        offset = end
    raise ValueError("Photo container is incomplete")


def _jpeg_dimensions(data: bytes) -> tuple[int, int]:
    if not data.startswith(b"\xff\xd8"):
        raise ValueError("Photo does not match its declared image type")
    offset = 2
    dimensions = None
    saw_scan = False
    segments = 0
    while offset < len(data):
        segments += 1
        if segments > 4096 or data[offset] != 0xFF:
            raise ValueError("Photo container is invalid")
        while offset < len(data) and data[offset] == 0xFF:
            offset += 1
        if offset >= len(data):
            break
        marker = data[offset]
        offset += 1
        if marker == 0xD9:
            if dimensions is None or not saw_scan or offset != len(data):
                raise ValueError("Photo container is incomplete")
            return dimensions
        if marker in {0x00, 0x01, 0xD8} or 0xD0 <= marker <= 0xD7:
            raise ValueError("Photo marker is invalid")
        if offset + 2 > len(data):
            break
        length = struct.unpack_from(">H", data, offset)[0]
        end = offset + length
        if length < 2 or end > len(data):
            break
        payload = data[offset + 2 : end]
        if marker in {0xC0, 0xC1, 0xC2}:
            if dimensions is not None or len(payload) < 6 or payload[0] != 8:
                raise ValueError("Photo frame is unsupported")
            height, width = struct.unpack_from(">HH", payload, 1)
            components = payload[5]
            if components not in {1, 3, 4} or len(payload) != 6 + 3 * components:
                raise ValueError("Photo frame is invalid")
            dimensions = _dimensions(width, height)
        elif 0xC0 <= marker <= 0xCF and marker not in {0xC4, 0xC8, 0xCC}:
            raise ValueError("Photo frame is unsupported")
        if marker == 0xDA:
            if dimensions is None or len(payload) < 6:
                raise ValueError("Photo scan is invalid")
            saw_scan = True
            # Entropy-coded bytes may contain escaped FF and restart markers.
            offset = end
            while offset < len(data):
                next_marker = data.find(b"\xff", offset)
                if next_marker < 0 or next_marker + 1 >= len(data):
                    raise ValueError("Photo scan is truncated")
                cursor = next_marker + 1
                while cursor < len(data) and data[cursor] == 0xFF:
                    cursor += 1
                if cursor >= len(data):
                    raise ValueError("Photo scan is truncated")
                if data[cursor] == 0 or 0xD0 <= data[cursor] <= 0xD7:
                    offset = cursor + 1
                    continue
                offset = next_marker
                break
        else:
            offset = end
    raise ValueError("Photo container is incomplete")


class AiModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid", strict=True, frozen=True, validate_default=True, hide_input_in_errors=True
    )


class ExtractionImage(AiModel):
    slot: ImageSlot
    mime_type: Literal["image/png", "image/jpeg"]
    data_base64: str = Field(min_length=1, max_length=MAX_IMAGE_BASE64, repr=False)

    @model_validator(mode="after")
    def bounded_photo(self) -> Self:
        try:
            data = base64.b64decode(self.data_base64, validate=True)
        except (ValueError, binascii.Error):
            raise ValueError("Photo must contain valid base64 image bytes") from None
        if not 1 <= len(data) <= MAX_IMAGE_BYTES:
            raise ValueError("Photo exceeds the supported byte bounds")
        if base64.b64encode(data).decode("ascii") != self.data_base64:
            raise ValueError("Photo base64 encoding must be canonical")
        if self.mime_type == "image/png":
            _png_dimensions(data)
        else:
            _jpeg_dimensions(data)
        return self


class ExtractionRequest(AiModel):
    images: list[ExtractionImage] = Field(min_length=1, max_length=3, repr=False)
    privacy_consent: Annotated[Literal[True], BeforeValidator(require_confirmation)]
    # Versioned terms acknowledgement from the app, not confirmation of facts.
    # Older clients retain their explicitly private extraction behavior.
    catalogue_contribution: Literal["machine-unverified-v1"] | None = None

    @model_validator(mode="after")
    def unique_photos(self) -> Self:
        slots = [image.slot for image in self.images]
        if len(slots) != len(set(slots)):
            raise ValueError("Each package side can occur only once")
        return self


class ExtractedIdentity(AiModel):
    name: ShortText | None
    brand: ShortText | None
    variant: ShortText | None
    quantity: ShortText | None
    barcode: Annotated[str, BeforeValidator(_barcode)] | None


class ExtractedBasis(AiModel):
    kind: Literal["quantity", "serving"]
    amount: Amount | None
    unit: Literal["g", "mL"] | None
    printed_text: PrintedText

    @model_validator(mode="after")
    def explicit_basis(self) -> Self:
        if (self.amount is None) != (self.unit is None):
            raise ValueError("Basis amount and unit must be present together")
        if self.kind == "quantity" and self.amount is None:
            raise ValueError("A quantity table needs a printed amount and unit")
        return self


class ExtractedNutrient(AiModel):
    nutrient: NutrientName
    value: Value | None
    unit: Literal["g", "mg", "ug", "kcal", "kJ"]
    qualifier: Literal["exact", "less_than", "less_than_or_equal", "approximate", "unknown"]
    printed_text: PrintedText

    @model_validator(mode="after")
    def value_and_unit(self) -> Self:
        if (self.unit in {"kcal", "kJ"}) != (self.nutrient == "energy"):
            raise ValueError("Energy and mass nutrients need compatible units")
        if (self.value is None) != (self.qualifier == "unknown"):
            raise ValueError("An unreadable value must remain unknown")
        return self


class ExtractedNutritionTable(AiModel):
    table_id: str = Field(min_length=1, max_length=64, pattern=r"^[A-Za-z0-9][A-Za-z0-9._:-]*$")
    basis: ExtractedBasis
    preparation: Literal["as_sold", "as_prepared", "unknown"]
    rows: list[ExtractedNutrient] = Field(min_length=1, max_length=32)


class NormalizedBox(AiModel):
    top: Coordinate
    left: Coordinate
    bottom: Coordinate
    right: Coordinate

    @model_validator(mode="after")
    def positive_area(self) -> Self:
        if self.top >= self.bottom or self.left >= self.right:
            raise ValueError("A highlighted region must have a positive area")
        return self


class ExtractedRegion(AiModel):
    slot: ImageSlot
    label: Literal["identity", "claim", "ingredients", "nutrition", "allergen", "barcode"]
    text: PrintedText
    box: NormalizedBox


class ExtractedLabel(AiModel):
    schema_version: Literal["1"] = "1"
    evidence: Literal["machine_extracted_unverified"] = "machine_extracted_unverified"
    identity: ExtractedIdentity
    ingredients: LabelText | None
    contains: LabelText | None
    may_contain: LabelText | None
    front_claims: list[ShortText] = Field(max_length=16)
    nutrition_tables: list[ExtractedNutritionTable] = Field(max_length=3)
    regions: list[ExtractedRegion] = Field(max_length=160)

    @model_validator(mode="after")
    def unique_tables(self) -> Self:
        identifiers = [table.table_id for table in self.nutrition_tables]
        if len(identifiers) != len(set(identifiers)):
            raise ValueError("Extracted table identifiers must be unique")
        return self
