# SPDX-License-Identifier: MIT
"""libopus lookup fallback (Windows opus.dll / STACKCHAN_LIBOPUS_PATH)."""

from __future__ import annotations

import ctypes.util

import pytest

from stackchan_mcp import opus_codec


@pytest.fixture(autouse=True)
def _restore(monkeypatch):
    original = ctypes.util.find_library
    monkeypatch.setattr(opus_codec, "_libopus_patched", False)
    yield
    ctypes.util.find_library = original


def test_candidates_windows_put_env_first_then_vendor(monkeypatch, tmp_path):
    monkeypatch.setattr(opus_codec.sys, "platform", "win32")
    monkeypatch.setenv("STACKCHAN_LIBOPUS_PATH", str(tmp_path / "custom.dll"))
    cands = opus_codec._opus_candidates()
    assert cands[0] == str(tmp_path / "custom.dll")
    assert any(c and c.endswith("opus.dll") and "vendor" in c for c in cands)


def test_candidates_linux_only_env(monkeypatch):
    monkeypatch.setattr(opus_codec.sys, "platform", "linux")
    monkeypatch.delenv("STACKCHAN_LIBOPUS_PATH", raising=False)
    assert opus_codec._opus_candidates() == [None]


def test_patch_uses_env_path_on_windows(monkeypatch, tmp_path):
    dll = tmp_path / "opus.dll"
    dll.write_bytes(b"")
    monkeypatch.setattr(opus_codec.sys, "platform", "win32")
    monkeypatch.setattr(ctypes.util, "find_library", lambda name: None)
    monkeypatch.setenv("STACKCHAN_LIBOPUS_PATH", str(dll))
    opus_codec._patch_find_library_for_brew()
    assert ctypes.util.find_library("opus") == str(dll)


def test_patch_leaves_find_library_alone_when_nothing_found(monkeypatch):
    monkeypatch.setattr(opus_codec.sys, "platform", "win32")
    monkeypatch.setattr(ctypes.util, "find_library", lambda name: None)
    monkeypatch.setenv("STACKCHAN_LIBOPUS_PATH", "/nonexistent/opus.dll")
    # vendor/opus.dll is not shipped, so no candidate exists.
    opus_codec._patch_find_library_for_brew()
    assert ctypes.util.find_library("opus") is None
