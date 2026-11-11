# SPDX-License-Identifier: MIT
from __future__ import annotations

import struct

from stackchan_mcp.mic_gain import MicGain, gain_db_from_env


def _pcm(*vals):
    return struct.pack("<%dh" % len(vals), *vals)


def test_off_by_default(monkeypatch):
    monkeypatch.delenv("STACKCHAN_MIC_GAIN_DB", raising=False)
    assert MicGain.from_env() is None


def test_invalid_and_clamped(monkeypatch):
    monkeypatch.setenv("STACKCHAN_MIC_GAIN_DB", "loud")
    assert gain_db_from_env() == 0.0
    monkeypatch.setenv("STACKCHAN_MIC_GAIN_DB", "90")
    assert gain_db_from_env() == 40.0


def test_boost_and_clip():
    g = MicGain(20.0)  # x10
    out = struct.unpack("<4h", g.apply(_pcm(100, -100, 5000, -5000)))
    assert out == (1000, -1000, 32767, -32768)
