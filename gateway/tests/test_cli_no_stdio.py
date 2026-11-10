# SPDX-License-Identifier: MIT
"""--no-stdio service mode and the Windows native-module preload."""

from __future__ import annotations

import asyncio
import sys
import types

import pytest

from stackchan_mcp import cli


def test_no_stdio_flag_parsed():
    args = cli._build_arg_parser().parse_args(["--no-stdio"])
    assert cli._no_stdio_requested(args)


def test_no_stdio_env(monkeypatch):
    monkeypatch.setenv("STACKCHAN_NO_STDIO", "1")
    args = cli._build_arg_parser().parse_args([])
    assert cli._no_stdio_requested(args)


def test_stdio_default(monkeypatch):
    monkeypatch.delenv("STACKCHAN_NO_STDIO", raising=False)
    args = cli._build_arg_parser().parse_args([])
    assert not cli._no_stdio_requested(args)


def test_main_passes_stdio_flag(monkeypatch):
    seen = {}

    async def fake_run(*, stdio=True):
        seen["stdio"] = stdio

    monkeypatch.setattr(cli, "_run", fake_run)
    monkeypatch.setattr(cli, "_load_dotenv", lambda: None)
    monkeypatch.delenv("STACKCHAN_NO_STDIO", raising=False)
    cli.main(["--no-stdio"])
    assert seen == {"stdio": False}


def test_preload_noop_off_windows(monkeypatch):
    monkeypatch.setattr(cli.sys, "platform", "linux")
    called = []
    monkeypatch.setattr("importlib.import_module", lambda n: called.append(n))
    cli._preload_native_modules()
    assert called == []


def test_preload_imports_and_tolerates_missing(monkeypatch):
    monkeypatch.setattr(cli.sys, "platform", "win32")
    called = []

    def fake_import(name):
        called.append(name)
        if name == "sherpa_onnx":
            raise ImportError("not installed")
        return types.ModuleType(name)

    monkeypatch.setattr("importlib.import_module", fake_import)
    cli._preload_native_modules()
    assert called == list(cli._WINDOWS_PRELOAD_MODULES)


def test_run_without_stdio_waits_and_stops_gateway(monkeypatch):
    events = []

    class FakeGateway:
        async def start(self):
            events.append("start")

        async def stop(self):
            events.append("stop")

    import stackchan_mcp.gateway as gw
    import stackchan_mcp.stdio_server as ss

    monkeypatch.setattr(gw, "get_gateway", lambda: FakeGateway())

    async def boom():
        raise AssertionError("stdio server must not start")

    monkeypatch.setattr(ss, "run_stdio_server", boom)
    monkeypatch.setattr(cli, "_preload_native_modules", lambda: None)

    async def scenario():
        task = asyncio.create_task(cli._run(stdio=False))
        await asyncio.sleep(0.05)
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task

    asyncio.run(scenario())
    assert events == ["start", "stop"]
