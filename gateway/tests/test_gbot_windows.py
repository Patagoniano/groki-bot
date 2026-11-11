# SPDX-License-Identifier: MIT
"""gbot is never run through a Windows batch file."""

from __future__ import annotations

import pytest

from stackchan_mcp import gbot_client
from stackchan_mcp.gbot_client import AskError, gbot_command


def test_plain_binary_unchanged(monkeypatch):
    monkeypatch.setattr(gbot_client.sys, "platform", "linux")
    assert gbot_command("/usr/local/bin/gbot") == ["/usr/local/bin/gbot"]


def test_windows_cmd_shim_runs_node_entry(monkeypatch, tmp_path):
    monkeypatch.setattr(gbot_client.sys, "platform", "win32")
    shim = tmp_path / "gbot.cmd"
    shim.write_text("@echo off\n")
    entry = tmp_path / "node_modules" / "grok-bot-cli" / "dist" / "bin" / "gbot.mjs"
    entry.parent.mkdir(parents=True)
    entry.write_text("")
    monkeypatch.setattr(gbot_client.shutil, "which", lambda name: "C:/node/node.exe" if name == "node" else None)
    assert gbot_command(str(shim)) == ["C:/node/node.exe", str(entry.resolve())]


def test_windows_cmd_shim_without_entry_is_refused(monkeypatch, tmp_path):
    monkeypatch.setattr(gbot_client.sys, "platform", "win32")
    shim = tmp_path / "gbot.cmd"
    shim.write_text("@echo off\n")
    monkeypatch.setattr(gbot_client.shutil, "which", lambda name: "C:/node/node.exe")
    with pytest.raises(AskError):
        gbot_command(str(shim))


def test_mjs_override_uses_node(monkeypatch):
    monkeypatch.setattr(gbot_client.shutil, "which", lambda name: "/usr/bin/node")
    assert gbot_command("/x/gbot.mjs") == ["/usr/bin/node", "/x/gbot.mjs"]
