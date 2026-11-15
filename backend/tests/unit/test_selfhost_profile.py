"""Profile inputs reject private metadata, malformed pixels and mutable provenance."""

import base64
import struct
import zlib

import pytest
from pydantic import ValidationError

from app.selfhost.profile import ProfileUpdate, avatar_bytes


def chunk(kind, content):
    return (
        struct.pack(">I", len(content))
        + kind
        + content
        + struct.pack(">I", zlib.crc32(kind + content) & 0xFFFFFFFF)
    )


def png(*, width=192, height=192, extra=b"", raw=None):
    pixels = b"\0" + bytes([42, 84, 126, 255]) * width
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + extra
        + chunk(b"IDAT", zlib.compress(pixels * height if raw is None else raw))
        + chunk(b"IEND", b"")
    )


def encoded(data):
    return base64.b64encode(data).decode("ascii")


def test_profile_accepts_valid_avatar_and_full_display_name():
    image = png()
    result = ProfileUpdate(
        expected_revision=0,
        display_name="V" * 160,
        gender="female",
        avatar_png_base64=encoded(image),
    )
    assert avatar_bytes(result.avatar_png_base64) == image
    assert result.gender == "female"
    assert encoded(image) not in repr(result)


@pytest.mark.parametrize(
    "values",
    [
        {"display_name": ""},
        {"display_name": "x" * 161},
        {"display_name": "x\x00y"},
        {"gender": "inferred"},
        {"expected_revision": True},
        {"expected_revision": -1},
        {"expected_revision": "0"},
        {"avatar_source": "google"},
        {"owner_id": "other-user"},
    ],
)
def test_profile_rejects_ambiguous_or_client_owned_identity_fields(values):
    with pytest.raises(ValidationError):
        ProfileUpdate.model_validate({"expected_revision": 0, **values})


@pytest.mark.parametrize(
    "image",
    [
        png(width=191),
        png(height=193),
        png()[:-1],
        png() + b"trailing",
        png(extra=chunk(b"eXIf", b"private metadata")),
        png(extra=chunk(b"tEXt", b"private text")),
        png(extra=chunk(b"acTL", bytes(8))),
        png(raw=b"\0"),
        png(raw=bytes(200000)),
        png(raw=(b"\x05" + bytes(768)) * 192),
        bytes(96 * 1024 + 1),
        b"not PNG",
    ],
    ids=[
        "width",
        "height",
        "truncated",
        "trailing",
        "exif",
        "text",
        "animated",
        "too_few_pixels",
        "decompression_limit",
        "invalid_filter",
        "encoded_size_limit",
        "invalid_signature",
    ],
)
def test_avatar_rejects_bad_dimensions_metadata_and_decompression(image):
    with pytest.raises(ValueError):
        avatar_bytes(encoded(image))


def test_avatar_verifies_crc_and_rejects_noncanonical_base64():
    image = bytearray(png())
    image[-5] ^= 1
    with pytest.raises(ValueError):
        avatar_bytes(encoded(image))
    for value in (encoded(png()) + "\n", "data:image/png;base64," + encoded(png()), "YWJj!"):
        with pytest.raises(ValueError):
            avatar_bytes(value)


def test_bounded_standard_colour_metadata_is_accepted():
    image = png(extra=chunk(b"sRGB", b"\0"))
    assert avatar_bytes(encoded(image)) == image
