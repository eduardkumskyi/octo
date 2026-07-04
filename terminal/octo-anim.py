#!/usr/bin/env python3
"""octo mascot — pixel-art terminal animation + live status display.

Zero dependencies (python3 stdlib). Renders a pixel octopus with waving
tentacles; below it, the current octo run status from .claude/octo/status.json
if present. Used by /octo:watch and as a friendly foreground while long
skills run.

Usage:
  octo-anim.py               # animate until Ctrl-C
  octo-anim.py --frames 40   # fixed number of frames, then exit
  octo-anim.py --once        # print a single frame (no ANSI cursor tricks)
  octo-anim.py --fps 8       # animation speed
"""

import argparse
import json
import math
import os
import signal
import sys
import time

# 256-color palette: char in art -> xterm bg color
PALETTE = {
    "P": 205,  # body pink
    "D": 168,  # shade pink
    "H": 218,  # highlight
    "W": 231,  # eye white
    "B": 16,   # pupil
    ".": None, # transparent
}

# Body: 16 columns wide. Tentacles are drawn programmatically below it.
BODY = [
    "....HHPPPPPP....",
    "..HHPPPPPPPPPP..",
    ".HPPPPPPPPPPPPP.",
    ".PPWWBPPPPWWBPP.",
    ".PPPPPPPPPPPPPP.",
    ".PDPPPPPPPPPPDP.",
    "..DPPPPPPPPPPD..",
]
BODY_BLINK_ROW = 3
BODY_BLINK = ".PPPPPPPPPPPPPP."  # eyes closed

WIDTH = 16
TENTACLE_ROWS = 4
TENTACLE_BASES = [2, 4, 6, 9, 11, 13]

RESET = "\x1b[0m"
HIDE_CUR = "\x1b[?25l"
SHOW_CUR = "\x1b[?25h"


def px(color):
    if color is None:
        return "  "
    return f"\x1b[48;5;{color}m  "


def tentacle_grid(t):
    """Return TENTACLE_ROWS rows of art chars with sine-offset tentacles."""
    grid = [["."] * WIDTH for _ in range(TENTACLE_ROWS)]
    for i, base in enumerate(TENTACLE_BASES):
        for row in range(TENTACLE_ROWS):
            sway = 1.3 * math.sin(t * 3.0 + row * 0.9 + i * 1.7)
            x = max(0, min(WIDTH - 1, base + round(sway)))
            grid[row][x] = "D" if row == TENTACLE_ROWS - 1 else "P"
    return ["".join(r) for r in grid]


def frame_lines(t):
    body = list(BODY)
    if int(t * 2) % 8 == 7:  # blink roughly every 4s
        body[BODY_BLINK_ROW] = BODY_BLINK
    lines = []
    for artrow in body + tentacle_grid(t):
        lines.append("".join(px(PALETTE[c]) for c in artrow) + RESET)
    return lines


def status_line():
    path = os.path.join(".claude", "octo", "status.json")
    try:
        with open(path) as f:
            s = json.load(f)
        phase = s.get("phase", "?")
        step = s.get("step", "")
        activity = s.get("activity", "")
        parts = [p for p in (phase, step, activity) if p]
        return "\x1b[38;5;205m◉\x1b[0m " + " · ".join(parts)
    except (OSError, ValueError):
        return "\x1b[38;5;244mocto is idle — waiting for a mission\x1b[0m"


def render(t):
    lines = frame_lines(t)
    lines.append("")
    lines.append(status_line())
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fps", type=float, default=8.0)
    ap.add_argument("--frames", type=int, default=0, help="0 = until Ctrl-C")
    ap.add_argument("--once", action="store_true")
    args = ap.parse_args()

    if args.once or not sys.stdout.isatty():
        print("\n".join(render(0.0)))
        return

    def restore(*_):
        sys.stdout.write(SHOW_CUR + RESET + "\n")
        sys.stdout.flush()
        sys.exit(0)

    signal.signal(signal.SIGINT, restore)
    signal.signal(signal.SIGTERM, restore)

    sys.stdout.write(HIDE_CUR)
    height = len(BODY) + TENTACLE_ROWS + 2
    first = True
    n = 0
    t0 = time.monotonic()
    try:
        while True:
            t = time.monotonic() - t0
            if not first:
                sys.stdout.write(f"\x1b[{height}A")
            first = False
            for line in render(t):
                sys.stdout.write("\x1b[2K" + line + "\n")
            sys.stdout.flush()
            n += 1
            if args.frames and n >= args.frames:
                break
            time.sleep(1.0 / args.fps)
    finally:
        sys.stdout.write(SHOW_CUR + RESET)
        sys.stdout.flush()


if __name__ == "__main__":
    main()
