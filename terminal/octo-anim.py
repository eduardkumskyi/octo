#!/usr/bin/env python3
"""octo wave — minimal one-line terminal animation + live status.

A flowing braille wave (the tentacle ripple) next to the octo mark, followed
by the current run status from .claude/octo/status.json. One line, no colors,
zero dependencies.

Usage:
  octo-anim.py               # animate until Ctrl-C
  octo-anim.py --frames 40   # fixed number of frames, then exit
  octo-anim.py --once        # print a single frame
  octo-anim.py --fps 12      # animation speed
  octo-anim.py --width 24    # wave width in characters
  octo-anim.py --plain       # no emoji (pure braille, safest fonts)
"""

import argparse
import json
import math
import os
import signal
import sys
import time

DOTBITS = {(0, 0): 0x01, (0, 1): 0x02, (0, 2): 0x04, (0, 3): 0x40,
           (1, 0): 0x08, (1, 1): 0x10, (1, 2): 0x20, (1, 3): 0x80}

HIDE_CUR = "\x1b[?25l"
SHOW_CUR = "\x1b[?25h"


def wave(phase, chars):
    """One braille row: a smooth sine wave, `chars` cells wide."""
    cols, rows = chars * 2, 4
    line = ""
    for cx in range(0, cols, 2):
        bits = 0
        for dx in range(2):
            x = cx + dx
            y = round((rows - 1) / 2 + (rows - 1) / 2 * math.sin(x * 0.35 - phase))
            bits |= DOTBITS[(dx, y)]
        line += chr(0x2800 + bits)
    return line


def status_line():
    path = os.path.join(".claude", "octo", "status.json")
    try:
        with open(path) as f:
            s = json.load(f)
        parts = [p for p in (s.get("phase"), s.get("step"), s.get("activity")) if p]
        return " · ".join(parts) if parts else "running"
    except (OSError, ValueError):
        return "idle — waiting for a mission"


def frame(t, width, plain):
    mark = "~" if plain else "🐙"
    return f"{mark} {wave(t * 4.0, width)}  {status_line()}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fps", type=float, default=12.0)
    ap.add_argument("--frames", type=int, default=0, help="0 = until Ctrl-C")
    ap.add_argument("--width", type=int, default=18, help="wave width in chars")
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--plain", action="store_true", help="no emoji")
    args = ap.parse_args()

    if args.once or not sys.stdout.isatty():
        print(frame(0.0, args.width, args.plain))
        return

    def restore(*_):
        sys.stdout.write(SHOW_CUR + "\n")
        sys.stdout.flush()
        sys.exit(0)

    signal.signal(signal.SIGINT, restore)
    signal.signal(signal.SIGTERM, restore)

    sys.stdout.write(HIDE_CUR)
    n = 0
    t0 = time.monotonic()
    try:
        while True:
            line = frame(time.monotonic() - t0, args.width, args.plain)
            sys.stdout.write("\r\x1b[2K" + line)
            sys.stdout.flush()
            n += 1
            if args.frames and n >= args.frames:
                break
            time.sleep(1.0 / args.fps)
    finally:
        sys.stdout.write(SHOW_CUR + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
