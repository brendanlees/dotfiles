#!/usr/bin/env python3
"""Display SplashBar's shared robot frame without querying or controlling Splash."""

import json
import math
from pathlib import Path
import subprocess
import time

FRAMES = {
    "working", "awake", "awake-blink", "sleeping", "sleeping-breathe",
    "sleeping-z", "waking-half", "waking-yawn", "loading", "off",
    "transition", "unknown",
}


def image_path(cache, now):
    try:
        state = json.loads((cache / "state.json").read_text())
        if not isinstance(state, dict) or state.get("schema") != 1:
            return None
        frame, updated = state.get("frame"), state.get("updated_at")
        if not isinstance(frame, str) or frame not in FRAMES:
            return None
        if type(updated) not in (int, float) or not math.isfinite(updated):
            return None
        if not 0 <= now - updated <= 5:
            return None
        image = cache / "icons" / (frame + ".png")
        return image if image.is_file() else None
    except (OSError, ValueError):
        return None


def main():
    cache = Path.home() / "Library/Caches/com.steadydigital.splashbar/sketchybar"
    image = image_path(cache, time.time())
    args = ["sketchybar", "--set", "splashbar"]
    if image is None:
        args += ["drawing=off", "background.image.drawing=off"]
    else:
        args += ["background.image=" + str(image), "background.image.drawing=on", "drawing=on"]
    subprocess.run(args, check=True)


if __name__ == "__main__":
    main()
