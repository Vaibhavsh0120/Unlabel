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

SCRIPT = Path(__file__).resolve().parents[3] / "scripts/data/acquire_india_catalogue.py"


def module():
    spec = importlib.util.spec_from_file_location("acquire_india_catalogue", SCRIPT)
    assert spec is not None and spec.loader is not None
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def test_acquisition_help_is_local_and_does_not_download():
    result = subprocess.run([sys.executable, str(SCRIPT), "--help"], capture_output=True, text=True)
    assert result.returncode == 0
    assert "official" in result.stdout


def test_csv_projection_preserves_identity_and_unknowns_without_aggregated_nutrition():
    source = io.BytesIO(
        b"code\tcountries_tags\tproduct_name\tingredients_text\tallergens\tsugars_100g\n"
        b"0123456789012\ten:india,en:france\tSynthetic oats\tOats, milk\ten:milk\t9\n"
        b"8900000000001\ten:india\tSparse\t\t\t0\n"
        b"8900000000002\ten:france\tOther\t\t\t0\n"
    )
    target = io.BytesIO()
    counts = module().project_csv(source, target)
    rows = [json.loads(line) for line in target.getvalue().splitlines()]
    assert counts == {"rows_read": 3, "india_rows": 2}
    assert rows[0]["code"] == "0123456789012"
    # Bare legacy allergens can omit ingredient-derived tags; it is not equivalent.
    assert rows[0]["allergens_tags"] is None
    assert rows[1]["ingredients_text"] is None
    assert rows[1]["allergens_tags"] is None
    assert "sugars_100g" not in rows[0]
    assert "nutrition" not in rows[0]


def test_nightly_tsv_keeps_literal_quotes_and_country_match_is_exact():
    source = io.BytesIO(
        b"code\tcountries_tags\tingredients_text\n"
        b'0123456789012\ten:india\t"Oats" with milk\\flavour\n'
        b"8900000000001\ten:indian-ocean\tRice\n"
    )
    target = io.BytesIO()
    counts = module().project_csv(source, target)
    assert counts == {"rows_read": 2, "india_rows": 1}
    assert json.loads(target.getvalue())["ingredients_text"] == '"Oats" with milk\\flavour'


@pytest.mark.parametrize(
    "source", [b"code\tname\n123\tName\n", b"code\tcountries_tags\n1\ten:india\textra\n"]
)
def test_incompatible_export_does_not_silently_claim_complete_projection(source):
    with pytest.raises(ValueError):
        module().project_csv(io.BytesIO(source), io.BytesIO())


def test_compressed_transfer_budget_is_checked_before_unbounded_read():
    meter = module().MeteredReader(io.BytesIO(b"123456"), max_bytes=5)
    with pytest.raises(ValueError):
        meter.read(6)


def test_metered_gzip_reads_forward_only_source_and_hashes_complete_compressed_bytes():
    decoded = b"code\tcountries_tags\n0123456789012\ten:india\n"
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


def csv_response(payload: bytes):
    class Response(io.BytesIO):
        status = 200
        url = "https://openfoodfacts-ds.s3.eu-west-3.amazonaws.com/en.openfoodfacts.org.products.csv.gz"
        headers = {"Content-Length": str(len(payload))}

    return Response(payload)


def test_successful_csv_acquisition_owns_binary_lock_and_cleans_it(tmp_path, monkeypatch):
    implementation = module()
    payload = gzip.compress(b"code\tcountries_tags\n0123456789012\ten:india\n")

    def network(*args, **kwargs):
        marker = (tmp_path / ".acquisition.lock").read_bytes()
        assert marker.startswith(b"pid=") and b" token=" in marker
        assert marker.endswith(b"\n") and b"\r" not in marker
        return csv_response(payload)

    monkeypatch.setattr(implementation.urllib.request, "urlopen", network)
    evidence = implementation.acquire(tmp_path)
    assert evidence["gzip_eof_verified"] is True
    assert not (tmp_path / ".acquisition.lock").exists()
    assert (tmp_path / "india-products.jsonl").is_file()


def test_csv_acquisition_preserves_foreign_replacement_lock(tmp_path, monkeypatch):
    implementation = module()
    payload = gzip.compress(b"code\tcountries_tags\n0123456789012\ten:india\n")
    lock = tmp_path / ".acquisition.lock"
    foreign = b"operator replacement lock; preserve for review\n"

    def network(*args, **kwargs):
        lock.unlink()
        lock.write_bytes(foreign)
        return csv_response(payload)

    monkeypatch.setattr(implementation.urllib.request, "urlopen", network)
    implementation.acquire(tmp_path)
    assert lock.read_bytes() == foreign


def test_acquisition_never_overwrites_files_appearing_during_download(tmp_path, monkeypatch):
    implementation = module()
    payload = gzip.compress(b"code\tcountries_tags\n0123456789012\ten:india\n")

    class Response(io.BytesIO):
        status = 200
        url = "https://openfoodfacts-ds.s3.eu-west-3.amazonaws.com/en.openfoodfacts.org.products.csv.gz"
        headers = {"Content-Length": str(len(payload))}

    def response(request, **kwargs):
        assert request.get_header("User-agent") == (
            f"Unlabel/{__version__} (https://github.com/Vaibhavsh0120/Unlabel)"
        )
        (tmp_path / "india-products.jsonl").write_bytes(b"existing source")
        (tmp_path / "acquisition.json").write_bytes(b"existing manifest")
        return Response(payload)

    monkeypatch.setattr(implementation.urllib.request, "urlopen", response)
    with pytest.raises((ValueError, FileExistsError)):
        implementation.acquire(tmp_path)
    assert (tmp_path / "india-products.jsonl").read_bytes() == b"existing source"
    assert (tmp_path / "acquisition.json").read_bytes() == b"existing manifest"


def test_locked_acquisition_refuses_before_network_or_file_mutation(tmp_path, monkeypatch):
    implementation = module()
    lock = tmp_path / ".acquisition.lock"
    lock.write_text("existing invocation")

    def forbidden(*args, **kwargs):
        raise AssertionError("Locked acquisition contacted network")

    monkeypatch.setattr(implementation.urllib.request, "urlopen", forbidden)
    with pytest.raises((ValueError, FileExistsError)):
        implementation.acquire(tmp_path)
    assert lock.read_text() == "existing invocation"
