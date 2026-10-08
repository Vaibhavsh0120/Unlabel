"""Synthetic photo containers and unverified label contract boundaries."""

import base64
import struct
import zlib

import pytest
from pydantic import ValidationError

from app.ai.models import (
    MAX_IMAGE_BYTES,
    ExtractedLabel,
    ExtractionImage,
    ExtractionRequest,
)


def png_bytes(width=2, height=2):
    def chunk(kind, content):
        return (
            struct.pack(">I", len(content))
            + kind
            + content
            + struct.pack(">I", zlib.crc32(kind + content) & 0xFFFFFFFF)
        )

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(b"\0\xff\xff\xff\xff\xff\xff" * 2))
        + chunk(b"IEND", b"")
    )


def jpeg_container(width=2, height=2):
    # A bounded marker-container fixture; the backend does not decompress photos.
    frame = bytes([8]) + struct.pack(">HH", height, width) + b"\x01\x01\x11\x00"
    scan = b"\x01\x01\x00\x00\x3f\x00"
    return (
        b"\xff\xd8\xff\xc0"
        + struct.pack(">H", len(frame) + 2)
        + frame
        + b"\xff\xda"
        + struct.pack(">H", len(scan) + 2)
        + scan
        + b"\x01\xff\x00\x02\xff\xd0\x03\xff\xd9"
    )


def image_dict(slot="back", data=None, mime_type="image/png"):
    return {
        "slot": slot,
        "mime_type": mime_type,
        "data_base64": base64.b64encode(png_bytes() if data is None else data).decode("ascii"),
    }


def extracted_dict():
    return {
        "schema_version": "1",
        "evidence": "machine_extracted_unverified",
        "identity": {
            "name": "Synthetic oats",
            "brand": "Synthetic brand",
            "variant": None,
            "quantity": "300 g",
            "barcode": "8901764051258",
        },
        "ingredients": "Oats, milk",
        "contains": "Milk",
        "may_contain": None,
        "front_claims": [],
        "nutrition_tables": [
            {
                "table_id": "back-100g",
                "basis": {
                    "kind": "quantity",
                    "amount": 100,
                    "unit": "g",
                    "printed_text": "Per 100 g",
                },
                "preparation": "as_sold",
                "rows": [
                    {
                        "nutrient": "sugars",
                        "value": 0,
                        "unit": "g",
                        "qualifier": "exact",
                        "printed_text": "Sugars 0 g",
                    },
                    {
                        "nutrient": "sodium",
                        "value": 5,
                        "unit": "mg",
                        "qualifier": "less_than",
                        "printed_text": "Sodium <5 mg",
                    },
                    {
                        "nutrient": "protein",
                        "value": None,
                        "unit": "g",
                        "qualifier": "unknown",
                        "printed_text": "Protein [unreadable]",
                    },
                ],
            }
        ],
        "regions": [
            {
                "slot": "back",
                "label": "ingredients",
                "text": "Oats, milk",
                "box": {"top": 0.1, "left": 0.1, "bottom": 0.5, "right": 0.8},
            }
        ],
    }


def test_photo_contract_accepts_valid_bounded_png_and_jpeg_containers():
    png = ExtractionImage.model_validate(image_dict())
    jpeg = ExtractionImage.model_validate(image_dict("front", jpeg_container(), "image/jpeg"))
    request = ExtractionRequest(images=[png, jpeg], privacy_consent=True)
    assert len(request.images) == 2
    assert png.data_base64 not in repr(request)
    assert png.data_base64 not in repr(png)


@pytest.mark.parametrize("consent", [False, 1, "true", None])
def test_only_explicit_boolean_true_authorizes_temporary_provider_transfer(consent):
    with pytest.raises(ValidationError):
        ExtractionRequest.model_validate({"images": [image_dict()], "privacy_consent": consent})


@pytest.mark.parametrize(
    "changes",
    [
        {"images": []},
        {"images": [image_dict()] * 2},
        {"images": [image_dict()] * 4},
        {"images": [image_dict()], "provider": "openai"},
        {"images": [image_dict()], "api_key": "caller-cannot-choose-a-key"},
    ],
)
def test_request_cannot_override_global_provider_and_has_distinct_bounded_slots(changes):
    with pytest.raises(ValidationError):
        ExtractionRequest.model_validate({"privacy_consent": True, **changes})


@pytest.mark.parametrize(
    "data,mime",
    [
        (b"not an image", "image/png"),
        (png_bytes(), "image/jpeg"),
        (jpeg_container(), "image/png"),
        (png_bytes()[:-1], "image/png"),
        (png_bytes() + b"trailing", "image/png"),
        (png_bytes(0, 2), "image/png"),
        (png_bytes(8193, 2), "image/png"),
        (png_bytes(6000, 6000), "image/png"),
        (jpeg_container(0, 2), "image/jpeg"),
        (jpeg_container(8193, 2), "image/jpeg"),
        (jpeg_container()[:-2], "image/jpeg"),
        (jpeg_container() + b"trailing", "image/jpeg"),
        (b"x" * (MAX_IMAGE_BYTES + 1), "image/png"),
    ],
    ids=[
        "unsupported",
        "png-as-jpeg",
        "jpeg-as-png",
        "png-truncated",
        "png-trailing",
        "png-zero",
        "png-edge",
        "png-pixels",
        "jpeg-zero",
        "jpeg-edge",
        "jpeg-truncated",
        "jpeg-trailing",
        "oversized-bytes",
    ],
)
def test_invalid_mismatched_truncated_and_oversized_images_are_rejected(data, mime):
    with pytest.raises(ValidationError):
        ExtractionImage.model_validate(image_dict(data=data, mime_type=mime))


def test_png_crc_and_header_are_verified_without_decompression():
    data = bytearray(png_bytes())
    data[25] ^= 1
    with pytest.raises(ValidationError):
        ExtractionImage.model_validate(image_dict(data=bytes(data)))


@pytest.mark.parametrize("data", ["abcd!", "data:image/png;base64,abcd", "YWJjZA", "YWJjZA==\n"])
def test_noncanonical_or_invalid_base64_is_rejected(data):
    with pytest.raises(ValidationError):
        ExtractionImage.model_validate({**image_dict(), "data_base64": data})


def test_machine_label_preserves_exact_zero_less_than_and_unknown_without_confirmation():
    label = ExtractedLabel.model_validate(extracted_dict())
    assert label.evidence == "machine_extracted_unverified"
    assert label.nutrition_tables[0].rows[0].value == 0
    assert label.nutrition_tables[0].rows[1].qualifier == "less_than"
    assert label.nutrition_tables[0].rows[2].value is None
    assert label.may_contain is None
    assert "confirmed" not in label.model_dump()


@pytest.mark.parametrize(
    "barcode", ["8901764051259", "0000000000000", "890 1764051258", 8901764051258, "٨٩٠١٧٦٤٠٥١٢٥٨"]
)
def test_machine_read_barcode_must_be_ascii_and_pass_the_gtin_check_digit(barcode):
    data = extracted_dict()
    data["identity"]["barcode"] = barcode
    with pytest.raises(ValidationError):
        ExtractedLabel.model_validate(data)


def test_missing_identity_and_nutrition_remain_unknown_not_invented():
    data = extracted_dict()
    data.update(
        identity=dict.fromkeys(data["identity"]),
        ingredients=None,
        contains=None,
        nutrition_tables=[],
        regions=[],
    )
    label = ExtractedLabel.model_validate(data)
    assert label.identity.name is None
    assert label.nutrition_tables == []
    assert label.ingredients is None


def test_printed_serving_is_allowed_without_an_inferred_mass():
    data = extracted_dict()
    data["nutrition_tables"][0]["basis"] = {
        "kind": "serving",
        "amount": None,
        "unit": None,
        "printed_text": "Per serving",
    }
    assert ExtractedLabel.model_validate(data).nutrition_tables[0].basis.amount is None


@pytest.mark.parametrize(
    "mutate",
    [
        lambda d: d.update(evidence="confirmed_label"),
        lambda d: d.update(score=85),
        lambda d: d.update(front_claims=["High protein"] * 17),
        lambda d: d.update(ingredients="Milk\0hidden"),
        lambda d: d["nutrition_tables"][0]["basis"].update(amount=None),
        lambda d: d["nutrition_tables"][0]["basis"].update(amount=0),
        lambda d: d["nutrition_tables"][0]["basis"].update(amount=True),
        lambda d: d["nutrition_tables"][0]["basis"].update(amount=float("inf")),
        lambda d: d["nutrition_tables"][0]["rows"][0].update(value=-1),
        lambda d: d["nutrition_tables"][0]["rows"][0].update(value=True),
        lambda d: d["nutrition_tables"][0]["rows"][0].update(value="2"),
        lambda d: d["nutrition_tables"][0]["rows"][0].update(value=None),
        lambda d: d["nutrition_tables"][0]["rows"][0].update(unit="kcal"),
        lambda d: d["nutrition_tables"][0]["rows"][2].update(qualifier="exact"),
        lambda d: d["regions"][0]["box"].update(right=0.05),
        lambda d: d["regions"][0]["box"].update(top=float("nan")),
        lambda d: d["regions"][0]["box"].update(bottom=1.1),
        lambda d: d["regions"][0].update(label="healthy"),
        lambda d: d["nutrition_tables"].append(d["nutrition_tables"][0]),
    ],
)
def test_unqualified_invented_and_invalid_measurements_do_not_cross_the_machine_contract(mutate):
    data = extracted_dict()
    mutate(data)
    with pytest.raises(ValidationError):
        ExtractedLabel.model_validate(data)
