# SPDX-License-Identifier: MIT
"""Fixed digital gain for decoded device microphone PCM.

Some boards deliver very quiet audio (AtomS3R + Atomic Voice Base: speech
around -55 dBFS at 30 cm because M5Unified sets the ES8311 PGA to its
minimum). ``STACKCHAN_MIC_GAIN_DB`` boosts the 16 kHz PCM before the wake
word gate and Gemini see it. Samples are clipped to int16. Default 0 (off).
"""

from __future__ import annotations

import array
import logging
import os
import sys

logger = logging.getLogger(__name__)

MAX_GAIN_DB = 40.0


def gain_db_from_env() -> float:
    raw = os.getenv("STACKCHAN_MIC_GAIN_DB", "").strip()
    if not raw:
        return 0.0
    try:
        value = float(raw)
    except ValueError:
        logger.warning("ignoring invalid STACKCHAN_MIC_GAIN_DB=%r", raw)
        return 0.0
    return max(-MAX_GAIN_DB, min(MAX_GAIN_DB, value))


class MicGain:
    def __init__(self, gain_db: float) -> None:
        self.gain_db = gain_db
        self._factor = 10.0 ** (gain_db / 20.0)

    @classmethod
    def from_env(cls) -> MicGain | None:
        db = gain_db_from_env()
        if db == 0.0:
            return None
        logger.info("device mic gain %+.1f dB (STACKCHAN_MIC_GAIN_DB)", db)
        return cls(db)

    def apply(self, pcm: bytes) -> bytes:
        if not pcm:
            return pcm
        samples = array.array("h")
        samples.frombytes(pcm[: len(pcm) // 2 * 2])
        if sys.byteorder != "little":
            samples.byteswap()
        f = self._factor
        out = array.array(
            "h",
            (32767 if v > 32767 else -32768 if v < -32768 else v
             for v in (int(s * f) for s in samples)),
        )
        if sys.byteorder != "little":
            out.byteswap()
        return out.tobytes()
