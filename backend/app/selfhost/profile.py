"""Bounded private profile contract and metadata-free avatar validation."""

import base64
import binascii
import struct
import zlib
from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, BeforeValidator, ConfigDict, Field, field_validator, model_validator

from app.community.models import visible_text

MAX_AVATAR_BYTES = 96 * 1024
MAX_PROFILE_BODY_BYTES = 144 * 1024
MAX_PROFILE_REVISION = 2_147_483_647
Revision = Annotated[int, Field(strict=True, ge=0, le=MAX_PROFILE_REVISION)]
DisplayName = Annotated[str, BeforeValidator(visible_text), Field(min_length=1, max_length=160)]


def avatar_bytes(value: str | None) -> bytes | None:
    if value is None:
        return None
    try:
        data = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error):
        raise ValueError("A valid PNG avatar is required") from None
    if not 1 <= len(data) <= MAX_AVATAR_BYTES or base64.b64encode(data).decode("ascii") != value:
        raise ValueError("Avatar exceeds its bounds or has noncanonical base64")
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Avatar must be PNG")
    offset, chunks, pixel_data, dimensions = 8, 0, bytearray(), None
    started_pixels = False
    metadata = set()
    while offset + 12 <= len(data):
        chunks += 1
        if chunks > 256:
            raise ValueError("Avatar contains too many chunks")
        length = struct.unpack_from(">I", data, offset)[0]
        end = offset + length + 12
        if end > len(data):
            raise ValueError("Avatar PNG is truncated")
        kind, content = data[offset + 4 : offset + 8], data[offset + 8 : end - 4]
        if zlib.crc32(kind + content) & 0xFFFFFFFF != struct.unpack_from(">I", data, end - 4)[0]:
            raise ValueError("Avatar PNG checksum is invalid")
        if kind == b"IHDR" and chunks == 1 and length == 13:
            width, height, depth, colour, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", content
            )
            if (
                (width, height) != (192, 192)
                or depth != 8
                or colour not in {2, 6}
                or (compression, filtering, interlace) != (0, 0, 0)
            ):
                raise ValueError("Avatar must be a noninterlaced 192 by 192 RGB or RGBA PNG")
            dimensions = 3 if colour == 2 else 4
        elif kind == b"IDAT" and dimensions is not None:
            started_pixels = True
            pixel_data.extend(content)
        elif kind == b"IEND" and length == 0 and end == len(data) and pixel_data:
            row_size = 1 + 192 * dimensions
            maximum = row_size * 192
            decoder = zlib.decompressobj()
            try:
                pixels = decoder.decompress(pixel_data, maximum + 1)
            except zlib.error:
                raise ValueError("Avatar pixels are invalid") from None
            if (
                len(pixels) != maximum
                or not decoder.eof
                or decoder.unused_data
                or decoder.unconsumed_tail
                or any(pixels[i] > 4 for i in range(0, maximum, row_size))
            ):
                raise ValueError("Avatar pixels are invalid")
            return data
        elif (
            dimensions is not None
            and not started_pixels
            and kind not in metadata
            and (
                kind == b"sRGB"
                and length == 1
                and content[0] <= 3
                or kind == b"gAMA"
                and length == 4
                or kind == b"cHRM"
                and length == 32
                or kind == b"pHYs"
                and length == 9
            )
        ):
            metadata.add(kind)  # Only colour/resolution data; no EXIF, text or profiles.
        else:
            raise ValueError("Avatar contains unsupported metadata or PNG chunks")
        offset = end
    raise ValueError("Avatar PNG is incomplete")


class ProfileModel(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, hide_input_in_errors=True)
    schema_version: Literal["1"] = "1"
    display_name: DisplayName | None = None
    gender: Literal["unset", "male", "female"] = "unset"
    avatar_png_base64: str | None = Field(default=None, max_length=131072, repr=False)

    @field_validator("avatar_png_base64")
    @classmethod
    def bounded_avatar(cls, value):
        avatar_bytes(value)
        return value


class ProfileUpdate(ProfileModel):
    expected_revision: Revision


class ProfileSnapshot(ProfileModel):
    revision: Revision = 0
    avatar_source: Literal["default", "google", "custom"] = "default"
    updated_at: datetime | None = None

    @model_validator(mode="after")
    def consistent_state(self):
        if (self.revision == 0) != (self.updated_at is None):
            raise ValueError("Profile revision and timestamp differ")
        if self.updated_at is not None and self.updated_at.tzinfo is None:
            raise ValueError("Profile timestamp must be aware")
        if (self.avatar_png_base64 is None) != (self.avatar_source == "default"):
            raise ValueError("Profile avatar and origin differ")
        return self
