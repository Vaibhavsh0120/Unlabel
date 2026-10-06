import importlib
import io
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]


@pytest.fixture
def progress_module(monkeypatch):
    monkeypatch.syspath_prepend(str(ROOT / "scripts"))
    return importlib.import_module("_progress")


class Terminal(io.StringIO):
    def isatty(self) -> bool:
        return True


def test_measured_progress_keeps_noninteractive_logs_plain(progress_module):
    output = io.StringIO()
    with progress_module.Progress("Synthetic bytes", total_bytes=4, stream=output) as progress:
        progress.advance(1)
        progress.advance(3)
        assert progress.thread is None
        assert "Verified" not in output.getvalue()
    text = output.getvalue()
    assert "Starting: Synthetic bytes (4 B)" in text
    assert "Verified: Synthetic bytes" in text
    assert ", 4 B)" in text
    assert "\r" not in text and "%" not in text


@pytest.mark.parametrize("completed", [3, 5])
def test_incomplete_or_excess_bytes_stop_without_success(progress_module, completed):
    output = io.StringIO()
    with pytest.raises(ValueError, match="expected byte count"):
        with progress_module.Progress("Synthetic bytes", total_bytes=4, stream=output) as progress:
            progress.advance(completed)
    assert "Stopped: Synthetic bytes" in output.getvalue()
    assert "Verified" not in output.getvalue()


@pytest.mark.parametrize("terminal", [False, True])
def test_exception_at_full_byte_count_never_reports_verification(progress_module, terminal):
    output = Terminal() if terminal else io.StringIO()
    with pytest.raises(KeyboardInterrupt):
        with progress_module.Progress("Synthetic bytes", total_bytes=4, stream=output) as progress:
            progress.advance(4)
            raise KeyboardInterrupt
    assert "Stopped: Synthetic bytes" in output.getvalue()
    assert "Verified" not in output.getvalue()


@pytest.mark.parametrize("total", [0, -1, True])
def test_invalid_total_is_rejected(progress_module, total):
    with pytest.raises(ValueError, match="positive byte count"):
        progress_module.Progress("Synthetic bytes", total_bytes=total)


def test_progress_cannot_move_backwards(progress_module):
    progress = progress_module.Progress("Synthetic bytes", total_bytes=4, stream=io.StringIO())
    with pytest.raises(ValueError, match="backwards"):
        progress.advance(-1)
    assert progress.completed_bytes == 0


@pytest.mark.parametrize("terminal", [False, True])
def test_external_tool_stages_use_no_animation_thread(progress_module, terminal):
    output = Terminal() if terminal else io.StringIO()
    with progress_module.Progress("Synthetic install", animate=False, stream=output) as progress:
        assert progress.thread is None
    assert "Done: Synthetic install" in output.getvalue()
    assert "\r" not in output.getvalue() and "%" not in output.getvalue()


def test_indeterminate_terminal_stage_stops_its_thread(progress_module):
    output = Terminal()
    with progress_module.Progress("Synthetic index", stream=output) as progress:
        assert progress.thread is not None
        assert "working; total unknown" in output.getvalue()
    assert not progress.thread.is_alive()
    assert "Done: Synthetic index" in output.getvalue()
    assert "Verified" not in output.getvalue() and "%" not in output.getvalue()


def test_terminal_byte_bar_shows_measured_completion(progress_module):
    output = Terminal()
    with progress_module.Progress("Synthetic bytes", total_bytes=4, stream=output) as progress:
        progress.advance(4)
    assert "[====================] 4 B/4 B" in output.getvalue()
    assert "Verified: Synthetic bytes" in output.getvalue()


def test_noninteractive_indeterminate_failure_has_no_thread_or_success(progress_module):
    output = io.StringIO()
    with pytest.raises(ValueError, match="synthetic tool failure"):
        with progress_module.Progress("Synthetic index", stream=output) as progress:
            assert progress.thread is None
            raise ValueError("synthetic tool failure")
    assert "Stopped: Synthetic index" in output.getvalue()
    assert "Done" not in output.getvalue() and "\r" not in output.getvalue()
