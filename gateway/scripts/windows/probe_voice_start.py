# SPDX-License-Identifier: MIT
"""Time each step of the Gemini voice backend start-up without the robot.

Mirrors GeminiVoiceProxy.start() up to (not including) the Gemini Live
connection, so a hang can be located. If a step blocks for 90 s, the Python
stack of every thread is written to logs/probe_voice_start.txt and the probe exits.
Run from gateway/:
  uv run --extra gemini-live --extra tts --extra wakeword python scripts/windows/probe_voice_start.py
"""

from __future__ import annotations

import faulthandler
import logging
import sys
import time
from pathlib import Path

GATEWAY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(GATEWAY))
LOG = GATEWAY / "logs" / "probe_voice_start.txt"
LOG.parent.mkdir(exist_ok=True)
out = LOG.open("w", encoding="utf-8", buffering=1)


def say(msg: str) -> None:
    line = f"[{time.strftime('%H:%M:%S')}] {msg}"
    print(line, flush=True)
    out.write(line + "\n")


faulthandler.dump_traceback_later(90, exit=True, file=out)
logging.basicConfig(level=logging.INFO, stream=out, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")


def step(name, fn):
    say(f"START {name}")
    t = time.monotonic()
    try:
        result = fn()
    except Exception as exc:  # report and continue
        say(f"FAIL  {name} after {time.monotonic() - t:.1f}s: {type(exc).__name__}: {exc}")
        return None
    say(f"OK    {name} in {time.monotonic() - t:.1f}s")
    faulthandler.cancel_dump_traceback_later()
    faulthandler.dump_traceback_later(90, exit=True, file=out)
    return result


def load_env():
    from dotenv import load_dotenv
    load_dotenv(GATEWAY / ".env")


def codec():
    from stackchan_mcp.opus_codec import StackchanOpusCodec
    c = StackchanOpusCodec()
    c.encode_pcm_24k(b"\x00" * 2880)  # force encoder creation
    return c


def edge_tts_import():
    from stackchan_mcp.edge_tts_provider import EdgeTTSProvider  # noqa: F401


def wake_gate():
    from stackchan_mcp.wake_gate import create_wake_gate_from_env
    return create_wake_gate_from_env()


def genai_import():
    from google import genai  # noqa: F401


say(f"python {sys.version.split()[0]} on {sys.platform}")
step("load .env", load_env)
step("Opus codec", codec)
step("edge-tts import", edge_tts_import)
gate = step("wake word gate (sherpa-onnx)", wake_gate)
say(f"wake gate = {type(gate).__name__ if gate is not None else None}")
step("google-genai import", genai_import)
say("done")
faulthandler.cancel_dump_traceback_later()
