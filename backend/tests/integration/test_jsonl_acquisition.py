import gzip
import hashlib
import importlib.util
import io
import json
import subprocess
import sys
from pathlib import Path

import pytest

from app import __version__

SCRIPT = Path(__file__).resolve().parents[3] / "scripts/acquire_india_jsonl.py"


def module():
    spec = importlib.util.spec_from_file_location("acquire_india_jsonl", SCRIPT)
    assert spec is not None and spec.loader is not None
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def source(*rows):
    return io.BytesIO(b"".join((json.dumps(row) + "\n").encode() for row in rows))


def product(code="8900000000001", **fields):
    return {"code": code, "countries_tags": ["en:india"], **fields}


def test_help_does_not_download():
    result = subprocess.run([sys.executable, str(SCRIPT), "--help"], capture_output=True, text=True)
    assert result.returncode == 0
    assert "official" in result.stdout


def test_projection_exact_country_and_direct_data_only():
    implementation = module()
    target = io.BytesIO()
    counts = implementation.project_jsonl(
        source(
            product(
                nutrition={
                    "aggregated_set": {"nutrients": {"sugars": {"value": 99}}},
                    "input_sets": [
                        {
                            "source": "packaging",
                            "preparation": "as_sold",
                            "per": "100g",
                            "per_quantity": 100,
                            "per_unit": "g",
                            "nutrients": {
                                "sugars": {"value": 0, "unit": "g", "value_computed": 99},
                                "potassium": {"value": 5},
                            },
                        }
                    ],
                },
                nutriments={"sugars_100g": 99},
                lc="en",
                images={
                    "uploaded": {"1": {"uploader": "private"}},
                    "selected": {
                        "front": {
                            "en": {
                                "rev": "3",
                                "generation": {"user": "private"},
                                "sizes": {"400": {"w": 200, "h": 400}, "full": {"w": 500}},
                            },
                            "fr": {"rev": "1"},
                        }
                    },
                },
            ),
            {"code": "8900000000002", "countries_tags": ["en:indian-ocean"]},
            {"code": "8900000000003"},
        ),
        target,
    )
    assert counts["rows_read"] == 3
    assert counts["india_rows"] == counts["supported_unique_barcodes"] == 1
    projected = json.loads(target.getvalue())
    assert projected["nutrition"]["input_sets"][0]["nutrients"] == {
        "sugars": {"value": 0, "unit": "g"}
    }
    assert "aggregated_set" not in projected["nutrition"]
    assert "nutriments" not in projected
    assert projected["nutrition_legacy_present"] is True
    assert projected["images"] == {
        "selected": {"front": {"en": {"rev": "3", "sizes": {"400": {"w": 200, "h": 400}}}}}
    }


@pytest.mark.parametrize(
    "payload",
    [
        b"[]\n",
        b'{"code":"1","code":"2"}\n',
        b'{"x":NaN}\n',
        b"not-json\n",
        b'{"countries_tags":"en:india"}\n',
    ],
)
def test_malformed_source_refuses_complete_claim(payload):
    with pytest.raises(ValueError):
        module().project_jsonl(io.BytesIO(payload), io.BytesIO())


def test_unsupported_source_barcode_preserved_and_duplicate_supported_refused():
    implementation = module()
    target = io.BytesIO()
    counts = implementation.project_jsonl(source(product("short"), product()), target)
    assert counts["unsupported_barcodes"] == 1
    assert json.loads(target.getvalue().splitlines()[0])["code"] == "short"
    with pytest.raises(ValueError, match="Duplicate"):
        implementation.project_jsonl(source(product(), product()), io.BytesIO())


def test_numeric_precision_is_preserved_as_invalid_instead_of_rounded():
    target = io.BytesIO()
    module().project_jsonl(
        io.BytesIO(
            b'{"code":"8900000000001","countries_tags":["en:india"],"nutrition":{"input_sets":[{"nutrients":{"sugars":{"value":0.1234567890123456789,"unit":"g"},"sodium":{"value":0.004,"unit":"g"}}}]}}\n'
        ),
        target,
    )
    values = json.loads(target.getvalue())["nutrition"]["input_sets"][0]["nutrients"]
    assert values["sugars"]["value"] == {"invalid_number": "0.1234567890123456789"}
    assert values["sodium"]["value"] == 0.004


@pytest.mark.parametrize("token", ["1e-1000", "1e1000", "0.1234567890123456789"])
def test_direct_numeric_underflow_overflow_and_precision_do_not_become_exact(token):
    target = io.BytesIO()
    payload = (
        '{"code":"8900000000001","countries_tags":["en:india"],"nutrition":{"input_sets":[{"nutrients":{"sugars":{"value":'
        + token
        + ',"unit":"g"}}}]}}\n'
    ).encode()
    module().project_jsonl(io.BytesIO(payload), target)
    assert json.loads(target.getvalue())["nutrition"]["input_sets"][0]["nutrients"]["sugars"][
        "value"
    ] == {"invalid_number": token}


@pytest.mark.parametrize(
    "bound",
    ["MAX_RECORD_BYTES", "MAX_DECODED_BYTES", "MAX_PROJECTED_RECORD_BYTES", "MAX_PROJECTION_BYTES"],
)
def test_read_and_projection_budgets_are_fail_closed(bound, monkeypatch):
    implementation = module()
    monkeypatch.setattr(implementation, bound, 10)
    with pytest.raises(ValueError):
        implementation.project_jsonl(source(product()), io.BytesIO())


def response(payload, *, url=None, length=None):
    class Response(io.BytesIO):
        status = 200
        url: str
        headers: dict[str, str]

    result = Response(payload)
    result.url = url or module().REDIRECT
    result.headers = {
        "Content-Length": str(len(payload) if length is None else length),
        "Last-Modified": "Tue, 06 Oct 2026 06:53:46 GMT",
    }
    return result


def test_acquisition_hashes_full_source_and_deterministic_projection(tmp_path, monkeypatch):
    implementation = module()
    decoded = source(product(schema_version=1004)).getvalue()
    payload = gzip.compress(decoded)

    def network(request, **kwargs):
        assert request.get_header("User-agent") == (
            f"Unlabel/{__version__} (https://github.com/Vaibhavsh0120/Unlabel)"
        )
        return response(payload)

    monkeypatch.setattr(implementation.urllib.request, "urlopen", network)
    evidence = implementation.acquire(tmp_path)
    projection = tmp_path / "india-products.jsonl.gz"
    assert evidence["compressed_sha256"] == hashlib.sha256(payload).hexdigest()
    assert evidence["compressed_bytes"] == len(payload)
    assert evidence["gzip_eof_verified"] is True
    assert evidence["exported_at"] == "2026-10-06T06:53:46+00:00"
    assert (
        hashlib.sha256(gzip.decompress(projection.read_bytes())).hexdigest()
        == evidence["projection_sha256"]
    )
    assert json.loads((tmp_path / "acquisition.json").read_text())["india_rows"] == 1
    assert not (tmp_path / ".jsonl-acquisition.lock").exists()
    other = tmp_path / "other"
    other.mkdir()
    second = implementation.acquire(other)
    assert second["projection_compressed_sha256"] == evidence["projection_compressed_sha256"]


def test_acquisition_lock_marker_has_exact_binary_bytes(tmp_path, monkeypatch):
    implementation = module()

    def network(*args, **kwargs):
        marker = (tmp_path / ".jsonl-acquisition.lock").read_bytes()
        assert marker.startswith(b"pid=") and marker.endswith(b"\n")
        assert b"\r" not in marker
        return response(gzip.compress(source(product()).getvalue()))

    monkeypatch.setattr(implementation.urllib.request, "urlopen", network)
    implementation.acquire(tmp_path)
    assert not (tmp_path / ".jsonl-acquisition.lock").exists()


@pytest.mark.parametrize("case", ["truncated", "crc", "length", "foreign", "oversize"])
def test_network_or_integrity_failure_never_publishes(tmp_path, monkeypatch, case):
    implementation = module()
    payload = gzip.compress(source(product()).getvalue())
    network_payload = payload[:-3] if case == "truncated" else payload
    if case == "crc":
        network_payload = payload[:-8] + bytes([payload[-8] ^ 1]) + payload[-7:]
    result = response(
        network_payload,
        url="https://example.com/source.gz" if case == "foreign" else None,
        length=len(payload) + 1 if case == "length" else None,
    )
    if case == "oversize":
        result.headers["Content-Length"] = str(implementation.MAX_COMPRESSED_BYTES + 1)
    monkeypatch.setattr(implementation.urllib.request, "urlopen", lambda *args, **kwargs: result)
    with pytest.raises((ValueError, OSError, EOFError)):
        implementation.acquire(tmp_path)
    assert list(tmp_path.iterdir()) == []


def test_existing_lock_and_racing_files_are_preserved(tmp_path, monkeypatch):
    implementation = module()
    lock = tmp_path / ".jsonl-acquisition.lock"
    lock.write_text("existing")
    monkeypatch.setattr(
        implementation.urllib.request,
        "urlopen",
        lambda *args, **kwargs: pytest.fail("Network attempted"),
    )
    with pytest.raises(FileExistsError):
        implementation.acquire(tmp_path)
    assert lock.read_text() == "existing"
    lock.unlink()

    def racing(*args, **kwargs):
        (tmp_path / "india-products.jsonl.gz").write_bytes(b"foreign source")
        return response(gzip.compress(source(product()).getvalue()))

    monkeypatch.setattr(implementation.urllib.request, "urlopen", racing)
    with pytest.raises(FileExistsError):
        implementation.acquire(tmp_path)
    assert (tmp_path / "india-products.jsonl.gz").read_bytes() == b"foreign source"


def test_meter_checks_bounded_reads_deadline_and_transfer_budget(monkeypatch):
    implementation = module()
    meter = implementation.MeteredReader(io.BytesIO(b"1234"), max_bytes=3)
    with pytest.raises(ValueError):
        meter.read()
    with pytest.raises(ValueError):
        meter.read(4)
    meter = implementation.MeteredReader(io.BytesIO(b"1"))
    monkeypatch.setattr(
        implementation.time, "monotonic", lambda: meter.started + implementation.MAX_SECONDS + 1
    )
    with pytest.raises(ValueError, match="deadline"):
        meter.read(1)


def test_metered_gzip_reads_forward_only_source_and_hashes_complete_compressed_bytes():
    decoded = source(product()).getvalue()
    compressed = gzip.compress(decoded)

    class ForwardOnly:
        def __init__(self):
            self.stream = io.BytesIO(compressed)

        def read(self, size: int = -1, /) -> bytes:
            assert 0 <= size <= 1024**2
            return self.stream.read(size)

    meter = module().MeteredReader(ForwardOnly())
    with gzip.GzipFile(fileobj=meter) as stream:
        assert stream.read(7) + stream.read() == decoded
    assert meter.bytes_read == len(compressed)
    assert meter.digest.hexdigest() == hashlib.sha256(compressed).hexdigest()


@pytest.mark.parametrize("offset,whence", [(0, 0), (2, 1), (0, 2)])
def test_meter_refuses_seek_without_rewinding_or_changing_count_and_digest(offset, whence):
    source = io.BytesIO(b"compressed-stream")
    meter = module().MeteredReader(source)
    assert meter.read(3) == b"com"
    position, count, digest = source.tell(), meter.bytes_read, meter.digest.hexdigest()
    with pytest.raises(io.UnsupportedOperation):
        meter.seek(offset, whence)
    assert (source.tell(), meter.bytes_read, meter.digest.hexdigest()) == (position, count, digest)


@pytest.mark.parametrize(
    "images,missing",
    [
        ({}, 1),
        ({"selected": {"front": {}}}, 1),
        ({"selected": {"front": {"en": {"rev": "3"}}}}, 0),
        ({"front_hi": {"rev": "2"}}, 0),
    ],
)
def test_image_availability_counts_actual_selected_descriptors(images, missing):
    counts = module().project_jsonl(source(product(lc="en", images=images)), io.BytesIO())
    assert counts["missing_selected_front_images"] == missing


def test_modified_owned_lock_is_left_for_operator_review(tmp_path, monkeypatch):
    implementation = module()

    def changed_lock(*args, **kwargs):
        (tmp_path / ".jsonl-acquisition.lock").write_text("another invocation")
        return response(gzip.compress(source(product()).getvalue()))

    monkeypatch.setattr(implementation.urllib.request, "urlopen", changed_lock)
    implementation.acquire(tmp_path)
    assert (tmp_path / ".jsonl-acquisition.lock").read_text() == "another invocation"


@pytest.mark.parametrize("value", ["Tue, 06 Oct 2026 06:53:46", "unparseable"])
def test_missing_timezone_or_bad_source_date_refused_before_projection(
    tmp_path, monkeypatch, value
):
    implementation = module()
    result = response(gzip.compress(source(product()).getvalue()))
    result.headers["Last-Modified"] = value
    monkeypatch.setattr(implementation.urllib.request, "urlopen", lambda *args, **kwargs: result)
    with pytest.raises(ValueError):
        implementation.acquire(tmp_path)
    assert list(tmp_path.iterdir()) == []


def test_original_over_budget_nutrient_container_cannot_become_valid_after_selection():
    nutrients = {f"unsupported-{index}": {"value": 1} for index in range(201)}
    projected = module().project_record(
        product(nutrition={"input_sets": [{"nutrients": nutrients}]})
    )
    assert projected["nutrition"]["input_sets"][0]["source_nutrient_count"] == 201
    assert "invalid_source_nutrient_count" in projected["nutrition"]["input_sets"][0]["nutrients"]
