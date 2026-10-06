"""Dependency-free setup progress with measured bytes and plain log output."""

import sys
import threading
import time
from types import TracebackType
from typing import Self, TextIO


def byte_size(value: int) -> str:
    amount = float(value)
    for unit in ("B", "KiB", "MiB", "GiB"):
        if amount < 1024 or unit == "GiB":
            return f"{amount:.1f} {unit}" if unit != "B" else f"{value} B"
        amount /= 1024
    raise AssertionError("Byte unit selection failed")


class Progress:
    """Mark success only after the wrapped work and its validation complete."""

    def __init__(
        self,
        label: str,
        *,
        total_bytes: int | None = None,
        animate: bool = True,
        stream: TextIO | None = None,
    ) -> None:
        if total_bytes is not None and (
            not isinstance(total_bytes, int)
            or isinstance(total_bytes, bool)
            or total_bytes <= 0
        ):
            raise ValueError("Progress total must be a positive byte count")
        self.label = label
        self.total_bytes = total_bytes
        self.completed_bytes = 0
        self.stream = stream if stream is not None else sys.stderr
        self.terminal = animate and self.stream.isatty()
        self.started = self.last_render = time.monotonic()
        self.stop = threading.Event()
        self.thread: threading.Thread | None = None

    def __enter__(self) -> Self:
        self.started = self.last_render = time.monotonic()
        if self.terminal:
            self._render()
            if self.total_bytes is None:
                self.thread = threading.Thread(target=self._pulse, daemon=True)
                self.thread.start()
        else:
            suffix = (
                f" ({byte_size(self.total_bytes)})"
                if self.total_bytes is not None
                else " (working; total unknown)"
            )
            print(f"Starting: {self.label}{suffix}", file=self.stream, flush=True)
        return self

    def advance(self, count: int) -> None:
        if count < 0:
            raise ValueError("Progress cannot move backwards")
        self.completed_bytes += count
        now = time.monotonic()
        if self.terminal and now - self.last_render >= 0.1:
            self._render()
            self.last_render = now

    def _pulse(self) -> None:
        while not self.stop.wait(0.2):
            self._render()

    def _render(self) -> None:
        elapsed = time.monotonic() - self.started
        if self.total_bytes is None:
            position = int(elapsed * 5) % 20
            bar = " " * position + "=" + " " * (19 - position)
            detail = "working; total unknown"
        else:
            filled = min(20, self.completed_bytes * 20 // self.total_bytes)
            bar = "=" * filled + " " * (20 - filled)
            detail = f"{byte_size(self.completed_bytes)}/{byte_size(self.total_bytes)}"
        print(
            f"\r{self.label}: [{bar}] {detail} ({elapsed:.1f}s)",
            end="",
            file=self.stream,
            flush=True,
        )

    def __exit__(
        self,
        error_type: type[BaseException] | None,
        error: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        self.stop.set()
        if self.thread is not None:
            self.thread.join()
        elapsed = time.monotonic() - self.started
        mismatched_count = (
            error_type is None
            and self.total_bytes is not None
            and self.completed_bytes != self.total_bytes
        )
        if self.terminal:
            if error_type is None and not mismatched_count:
                self._render()
            print(file=self.stream, flush=True)
        if error_type is not None or mismatched_count:
            status = "Stopped"
        elif self.total_bytes is not None:
            status = "Verified"
        else:
            status = "Done"
        measured = (
            f", {byte_size(self.completed_bytes)}"
            if self.total_bytes is not None
            else ""
        )
        print(
            f"{status}: {self.label} ({elapsed:.1f}s{measured})",
            file=self.stream,
            flush=True,
        )
        if mismatched_count:
            raise ValueError("Measured progress differs from the expected byte count")
