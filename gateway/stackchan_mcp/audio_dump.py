# SPDX-License-Identifier: MIT
"""Opt-in capture of decoded device microphone audio for debugging.

Off unless ``STACKCHAN_AUDIO_DUMP_DIR`` is set. Each device connection writes
one 16 kHz mono 16-bit WAV of the PCM exactly as the wake word gate sees it,
capped at ``STACKCHAN_AUDIO_DUMP_SECONDS`` (default 60). The recording holds
whatever the robot's microphone picked up, so keep the directory local and
delete it after use.
"""

from __future__ import annotations

import logging
import os
import time
import wave
from pathlib import Path

logger = logging.getLogger(__name__)

SAMPLE_RATE = 16000
BYTES_PER_SECOND = SAMPLE_RATE * 2


class DeviceAudioDump:
    def __init__(self, directory: str | Path, max_seconds: float = 60.0, label: str = "device") -> None:
        self._dir = Path(directory)
        self._limit = int(max_seconds * BYTES_PER_SECOND)
        self._written = 0
        self._label = "".join(c if c.isalnum() else "-" for c in label)
        self._wav: wave.Wave_write | None = None
        self.path: Path | None = None
        self._done = False

    @classmethod
    def from_env(cls, label: str = "device") -> DeviceAudioDump | None:
        directory = os.getenv("STACKCHAN_AUDIO_DUMP_DIR", "").strip()
        if not directory:
            return None
        try:
            seconds = float(os.getenv("STACKCHAN_AUDIO_DUMP_SECONDS", "60"))
        except ValueError:
            seconds = 60.0
        return cls(directory, max_seconds=seconds, label=label)

    def write(self, pcm: bytes) -> None:
        if self._done or not pcm:
            return
        try:
            if self._wav is None:
                self._dir.mkdir(parents=True, exist_ok=True)
                stamp = time.strftime("%Y%m%d-%H%M%S")
                self.path = self._dir / f"mic-{stamp}-{self._label}.wav"
                self._wav = wave.open(str(self.path), "wb")
                self._wav.setnchannels(1)
                self._wav.setsampwidth(2)
                self._wav.setframerate(SAMPLE_RATE)
                logger.info("recording device audio to %s", self.path)
            room = self._limit - self._written
            chunk = pcm[: max(room, 0) // 2 * 2]
            if chunk:
                self._wav.writeframes(chunk)
                self._written += len(chunk)
            if self._written >= self._limit:
                self.close()
        except OSError as exc:
            logger.warning("audio dump disabled: %s", exc)
            self._done = True

    def close(self) -> None:
        if self._wav is not None:
            try:
                self._wav.close()
            finally:
                self._wav = None
                logger.info("device audio recording closed: %s (%.1f s)",
                            self.path, self._written / BYTES_PER_SECOND)
        self._done = True
