import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def module():
    spec = importlib.util.spec_from_file_location(
        "workspace_validator", ROOT / "scripts/validate_workspace.py"
    )
    assert spec is not None and spec.loader is not None
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def test_validator_reports_source_errors_without_disclosing_contents(tmp_path):
    for name, content in {
        "broken.py": 'value = "fixture-private" +\n',
        "broken.json": '{"fixture-private":}',
        "broken.toml": "[project\nfixture-private = 1",
        "README.md": "[Good](<with space.md>) [Bad](missing.md) [Web](https://example.test)",
        "with space.md": "# Existing target\n",
    }.items():
        (tmp_path / name).write_text(content, encoding="utf-8")
    result = module().validate(
        tmp_path, [Path(name) for name in ("broken.py", "broken.json", "broken.toml", "README.md")]
    )
    assert result["counts"]["local_links"] == 2
    assert len(result["errors"]) == 4
    assert "fixture-private" not in str(result)


def test_validator_detects_private_key_material_without_printing_it(tmp_path):
    key = "AGE-SECRET-KEY-" + "A" * 59
    (tmp_path / "secret.txt").write_text(key, encoding="utf-8")
    result = module().validate(tmp_path, [Path("secret.txt")])
    assert result["errors"] == ["secret.txt: private key material must remain untracked"]
    assert key not in str(result)


def test_validator_skips_deleted_and_generated_files_and_decodes_local_links(tmp_path):
    (tmp_path / "readme.md").write_text("[Doc](with%20space.md#anchor)\n", encoding="utf-8")
    (tmp_path / "with space.md").write_text("# anchor\n", encoding="utf-8")
    (tmp_path / "output.png").write_bytes(b"binary")
    result = module().validate(
        tmp_path, [Path("readme.md"), Path("deleted.py"), Path("output.png")]
    )
    assert result["errors"] == []
    assert result["counts"]["markdown"] == 1
