import importlib.util
import sqlite3
from contextlib import closing
from pathlib import Path

import pytest


def implementation():
    path = Path(__file__).resolve().parents[3] / "scripts/data/backup_catalogue.py"
    spec = importlib.util.spec_from_file_location("catalogue_backup", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_backup_preserves_all_tables_and_new_unbundled_records(tmp_path):
    source = tmp_path / "source.sqlite3"
    with closing(sqlite3.connect(source)) as connection:
        connection.execute("CREATE TABLE products (id TEXT PRIMARY KEY, payload TEXT)")
        connection.execute("CREATE TABLE newly_researched (id TEXT PRIMARY KEY, payload TEXT)")
        connection.execute("INSERT INTO products VALUES (?, ?)", ("old", "known"))
        connection.execute("INSERT INTO newly_researched VALUES (?, ?)", ("new", "new facts"))
        connection.commit()
    original = source.read_bytes()
    module = implementation()
    destination = tmp_path / "backup.sqlite3"
    receipt = module.backup(source, destination)
    assert source.read_bytes() == original
    assert receipt["tables"]["newly_researched"]["rows"] == 1
    with closing(sqlite3.connect(destination)) as copy:
        assert copy.execute("SELECT payload FROM newly_researched").fetchone() == ("new facts",)
        assert module.logical_inventory(copy) == receipt["tables"]
    assert not list(tmp_path.glob(".catalogue-backup-*"))


def test_backup_never_replaces_an_existing_destination(tmp_path):
    source = tmp_path / "source.sqlite3"
    with closing(sqlite3.connect(source)) as connection:
        connection.execute("CREATE TABLE products (id TEXT)")
    destination = tmp_path / "backup.sqlite3"
    destination.write_bytes(b"existing backup")
    with pytest.raises(ValueError):
        implementation().backup(source, destination)
    assert destination.read_bytes() == b"existing backup"
