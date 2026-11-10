# SPDX-License-Identifier: MIT
from __future__ import annotations

import wave

from stackchan_mcp.audio_dump import BYTES_PER_SECOND, DeviceAudioDump


def test_disabled_without_env(monkeypatch):
    monkeypatch.delenv("STACKCHAN_AUDIO_DUMP_DIR", raising=False)
    assert DeviceAudioDump.from_env() is None


def test_writes_wav_and_caps_length(monkeypatch, tmp_path):
    monkeypatch.setenv("STACKCHAN_AUDIO_DUMP_DIR", str(tmp_path))
    monkeypatch.setenv("STACKCHAN_AUDIO_DUMP_SECONDS", "1")
    dump = DeviceAudioDump.from_env(label="7c:e8")
    for _ in range(5):
        dump.write(b"\x01\x00" * 8000)  # 0.5 s each
    dump.close()
    files = list(tmp_path.glob("mic-*-7c-e8.wav"))
    assert len(files) == 1
    with wave.open(str(files[0])) as w:
        assert w.getframerate() == 16000
        assert w.getnchannels() == 1
        assert w.getnframes() * 2 == BYTES_PER_SECOND
