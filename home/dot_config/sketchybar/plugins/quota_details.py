#!/usr/bin/env python3
"""Label cached quota bars and show details without opening the native menu bar."""

import fcntl
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time


def sketchybar(*args):
    return subprocess.run(
        ["sketchybar", *args], capture_output=True, text=True, check=True
    ).stdout


def cache_dir():
    return Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))


def display_mode():
    try:
        mode = (cache_dir() / "sketchybar/quota-mode").read_text().strip()
    except FileNotFoundError:
        mode = os.environ.get("SKETCHYBAR_QUOTA_MODE", "remaining")
    return mode if mode in ("used", "remaining") else "remaining"


def percentage(window, mode):
    if window.get("usageKnown") is False:
        return None
    value = window.get(mode + "Percent")
    if value is None:
        other = window.get(("remaining" if mode == "used" else "used") + "Percent")
        if other is not None:
            value = 100 - other
    return value


def percent_label(window, mode):
    value = percentage(window, mode)
    if value is None:
        return "unknown"
    return f"{value:.0f}% {'used' if mode == 'used' else 'left'}"


def duration(minutes):
    if minutes is None:
        return "unknown"
    minutes = max(0, int(minutes))
    days, rest = divmod(minutes, 1440)
    hours, mins = divmod(rest, 60)
    if days:
        return f"{days}d" + (f" {hours}h" if hours else "")
    if hours:
        return f"{hours}h" + (f" {mins}m" if mins else "")
    return f"{mins}m"


def read_metrics(config):
    renderer = config / "vendor/showy-quota/bin/showy-quota-render"
    result = subprocess.run(
        [str(renderer), "--emit", "metrics", "--from-cache"],
        capture_output=True, text=True, check=False,
    )
    try:
        metrics = json.loads(result.stdout) if result.returncode == 0 else []
    except json.JSONDecodeError:
        metrics = []

    # The renderer omits plan identity and balance-only providers. Retain just
    # the Codex subscription signal and OpenRouter's monetary units from cache.
    try:
        raw = json.loads((cache_dir() / "showy-quota/usage.json").read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return metrics
    for provider in raw.get("providers", []):
        usage = provider.get("usage") or {}
        if provider.get("provider") == "codex":
            codex = next((p for p in metrics if p["provider"] == "codex"), None)
            if codex is None:
                codex = {"provider": "codex", "windows": {}, "error": provider.get("error")}
                metrics.append(codex)
            # CodexBar publishes the plan as loginMethod. Missing identity or a
            # fetch error is not evidence of cancellation; hide only known free plans.
            plan = (usage.get("identity") or {}).get("loginMethod") or usage.get("loginMethod") or ""
            codex["unsubscribed"] = plan.strip().lower().replace("_", " ") in (
                "free", "guest", "free workspace",
            )
            continue
        if provider.get("provider") != "openrouter":
            continue
        credits = {
            row["label"]: row["value"]
            for section in usage.get("details", []) if section.get("title") == "Credits"
            for row in section.get("rows", [])
        }
        if not credits and not provider.get("error"):
            continue
        metrics = [p for p in metrics if p["provider"] != "openrouter"]
        metrics.append({
            "provider": "openrouter", "windows": {}, "error": provider.get("error"),
            "credits": {"remaining": credits.get("Remaining")},
        })
    return metrics


def credit_label(provider):
    if provider.get("error"):
        return "unavailable"
    # Credits are a current balance, independent of the quota percentage mode.
    value = provider.get("credits", {}).get("remaining")
    return value if value is not None else "unknown"


def details(metrics, mode):
    for provider in metrics:
        yield provider["provider"].upper()
        if provider.get("error"):
            error = provider["error"]
            yield error.get("message", "Usage unavailable") if isinstance(error, dict) else str(error)
            continue
        if "credits" in provider:
            yield "Credits  ·  " + credit_label(provider)
        windows = [
            (duration(w["windowMinutes"]) if w.get("windowMinutes") else role, w)
            for role, w in provider.get("windows", {}).items() if w
        ]
        windows += [
            (f"{w['title']} · {duration(w.get('windowMinutes'))}", w)
            for w in provider.get("extraRateWindows", [])
        ]
        for label, window in windows:
            reset = duration(window.get("minutesUntilReset"))
            yield f"{label}  ·  {percent_label(window, mode)}  ·  resets in {reset}"


def standard_windows(provider):
    return [] if provider.get("error") else [
        w for w in provider.get("windows", {}).values() if w
    ][:2]


def strip_windows(provider):
    windows = standard_windows(provider)
    if provider["provider"] == "codex" and windows:
        # One Codex lane keeps the shared column at three rows. The menu still
        # exposes every window; prefer the weekly cap over its session quota.
        weekly = next((w for w in windows if w.get("windowMinutes") == 10080), windows[0])
        return [weekly]
    return windows


def window_color(window):
    remaining = percentage(window, "remaining")
    if remaining is None:
        return "0x00000000"
    color = os.environ["RED" if remaining < 15 else "YELLOW" if remaining < 40 else "MUTED"]
    if (window.get("windowMinutes") or 0) >= 10080:
        # Weekly caps keep the existing dimmer styling; severity always follows
        # remaining headroom, even when the user chooses a used-percent display.
        rgb = int(color[-6:], 16)
        color = "0xff" + "".join(f"{int(((rgb >> shift) & 255) * 0.65):02x}" for shift in (16, 8, 0))
    return color


def cache_notice(config):
    result = subprocess.run(
        [str(config / "vendor/showy-quota/bin/showy-quota-render"), "--emit", "sketchybar", "--from-cache"],
        capture_output=True, text=True, check=False,
    )
    # The upstream header retains its freshness and degraded-CLI diagnostics.
    flags = result.stdout.splitlines()[0].split("\x1f") if result.returncode == 0 and result.stdout else []
    return " · ".join(label for flag, label in zip(flags, ("stale", "CLI")) if flag == "1")


def render_strip(config, metrics, items, mode, close_popup=False):
    providers = [p for p in metrics if p["provider"] != "openrouter" and not p.get("unsubscribed")]
    claude = next((p for p in providers if p["provider"] == "claude"), None)
    codex = next((p for p in providers if p["provider"] == "codex"), None)
    groups = [[p] for p in providers if p["provider"] not in ("claude", "codex")]
    if claude or codex:
        groups.insert(0, [p for p in (claude, codex) if p is not None])

    font = "JetBrainsMono Nerd Font Mono:Regular:10.0"
    # Keep total capacity visible behind the used portion without competing with it.
    track_color = "0x40" + os.environ["MUTED"][-6:] if mode == "used" else os.environ["SURFACE"]
    click = shlex.quote(str(config / "plugins/quota.sh")) + " toggle"
    definitions = []

    def item(name, kind, properties):
        definitions.append((name, kind, [
            "position=right", "padding_left=0", "padding_right=0",
            "background.drawing=off", "icon.drawing=off", "label.drawing=off",
            "drawing=on", "click_script=" + click, *properties,
        ]))

    notice = cache_notice(config)
    item("showy_quota.status", "item", [
        "width=dynamic", "label.drawing=on", "label=" + notice,
        "label.color=" + os.environ["YELLOW"], "label.font=" + font,
        "drawing=" + ("on" if notice and groups else "off"),
    ])
    # Right-side, zero-width rows extend left; reserve one slot for each column.
    for group in reversed(groups):
        rows = [
            (provider, index, window)
            for provider in group
            for index, window in enumerate(strip_windows(provider) or [{}])
        ]
        offsets = {1: [0], 2: [7, -7], 3: [11, 0, -11]}[len(rows)]
        compact = len(rows) == 3
        row_font = "JetBrainsMono Nerd Font Mono:Regular:" + ("9.0" if compact else "10.0")
        label_width = (38 if compact else 42) if mode == "used" else (54 if compact else 60)
        slot_width = int(os.environ["SHOWY_QUOTA_SKETCHYBAR_BAR_WIDTH"]) - (60 - label_width)
        for (provider, index, window), y in reversed(list(zip(rows, offsets))):
            prefix = "showy_quota." + provider["provider"]
            name = prefix + (".primary" if index == 0 else ".secondary")
            value = percentage(window, mode)
            fill = 0 if value is None else round(value)
            label = "no data" if provider.get("error") else percent_label(window, mode).removesuffix(" used")
            item(name, "slider", [
                "width=0", f"y_offset={y}",
                "icon=" + (duration(window["windowMinutes"]) if window.get("windowMinutes") else "?"),
                "icon.drawing=on", "icon.font=" + row_font, "icon.color=" + os.environ["MUTED"],
                "icon.width=20", "icon.align=left", "icon.padding_left=0", "icon.padding_right=4",
                "label=" + label, "label.drawing=on", "label.font=" + row_font,
                "label.color=" + os.environ["MUTED"], f"label.width={label_width}", "label.align=left",
                "label.padding_left=4", "label.padding_right=0",
                "slider.width=" + os.environ["SHOWY_QUOTA_PNG_BAR_W"],
                f"slider.percentage={fill}", "slider.highlight_color=" + window_color(window),
                "slider.background.color=" + track_color,
                "slider.background.height=" + ("4" if compact else "6"),
                "slider.background.corner_radius=" + ("2" if compact else "3"),
                "slider.knob.drawing=off",
                f'click_script=sketchybar --set "$NAME" slider.percentage={fill}; {click}',
            ])
        item("showy_quota." + group[0]["provider"] + ".slot", "item", [
            f"width={slot_width}",
        ])
        for index in reversed(range(len(group))):
            provider = group[index]
            name = provider["provider"]
            glyph = {"codex": ":codex:", "claude": ":claude:", "opencode": ":opencode:", "opencodego": ":opencode:"}.get(name)
            icon_font = "sketchybar-app-font:Regular:" + ("9.0" if compact else "11.0") if glyph else row_font
            provider_offsets = [y for (p, _, _), y in zip(rows, offsets) if p is provider]
            icon_y = round(sum(provider_offsets) / len(provider_offsets))
            item("showy_quota." + name + ".icon", "item", [
                "width=" + ("0" if index else "24"),
                f"y_offset={icon_y}",
                "icon=" + (glyph or name[:2].upper()), "icon.drawing=on", "icon.font=" + icon_font,
                "icon.color=" + os.environ["YELLOW" if provider.get("error") else "MUTED"],
                "icon.width=24", "icon.align=center", "icon.padding_left=0", "icon.padding_right=0",
            ])

    names = [name for name, _, _ in definitions]
    owned = [n for n in items if n.startswith("showy_quota.") and n != "showy_quota.trigger"]
    rebuild = set(owned) != set(names) or "showy_quota_bracket" not in items
    args = []
    if rebuild and "showy_quota_bracket" in items:
        args += ["--remove", "showy_quota_bracket"]
    for name in owned:
        if name not in names:
            args += ["--remove", name]
    for name, kind, properties in definitions:
        if name not in items:
            args += ["--add", kind, name, "right"]
            if kind == "slider":
                args += [os.environ["SHOWY_QUOTA_PNG_BAR_W"]]
        args += ["--set", name, *properties]
        if close_popup and name.endswith(".icon"):
            args += ["popup.drawing=off"]
    if rebuild:
        # Right-side order is reversed; keep the separate oMLX pill left of quotas.
        order = ["showy_quota.trigger", *names]
        if "omlx" in items:
            order.append("omlx")
        args += ["--reorder", *order,
                 "--add", "bracket", "showy_quota_bracket", *names]
    args += [
        "--set", "showy_quota_bracket", "drawing=" + ("on" if groups else "off"),
        "background.drawing=on", "background.color=" + os.environ["PILL_BG"],
        "background.border_color=" + os.environ["SURFACE"], "background.border_width=1",
        "background.height=36", "background.corner_radius=8",
    ]
    # Publish only the finished layout. No intermediate compact/remaining pass,
    # and no teardown or reorder during ordinary refreshes.
    sketchybar(*args)


def toggle_popup(config, metrics, items, mode):
    anchors = [
        name for name in items
        if name.startswith("showy_quota.") and name.endswith(".icon")
    ]
    if not anchors:
        return
    clicked = os.environ.get("NAME", "").rsplit(".", 1)[0] + ".icon"
    anchor = clicked if clicked in anchors else anchors[0]
    showing = json.loads(sketchybar("--query", anchor)).get("popup", {}).get("drawing", "off")
    sketchybar("--set", "/showy_quota\\..*\\.icon$/", "popup.drawing=off")
    if showing in ("on", True):
        return

    cache = cache_dir() / "showy-quota/usage.json"
    age = duration((time.time() - cache.stat().st_mtime) / 60) if cache.exists() else "unknown"
    lines = [f"Cached usage · updated {age} ago", *details(metrics, mode)]
    if not metrics:
        lines.append("Usage unavailable - waiting for a successful refresh")

    sketchybar("--remove", "/quota_detail\\..*/")
    args = [
        "--set", anchor, "popup.height=26", "popup.align=right",
        "popup.background.color=" + os.environ["POPUP_BACKGROUND_COLOR"],
        "popup.background.border_color=" + os.environ["POPUP_BORDER_COLOR"],
    ]
    for index, line in enumerate(lines):
        args += [
            "--add", "item", f"quota_detail.{index}", f"popup.{anchor}",
            "--set", f"quota_detail.{index}", "icon.drawing=off",
            "background.drawing=off", "label=" + line,
            "label.color=" + os.environ["WHITE"],
            "label.font=JetBrainsMono Nerd Font Mono:Regular:12.0",
            "label.padding_left=12", "label.padding_right=12",
        ]
    other_mode = "used" if mode == "remaining" else "remaining"
    args += [
        "--add", "item", "quota_detail.mode", f"popup.{anchor}",
        "--set", "quota_detail.mode", "icon.drawing=off", "background.drawing=off",
        f"label=Show {other_mode} instead", "label.color=" + os.environ["MUTED"],
        "label.font=JetBrainsMono Nerd Font Mono:Regular:12.0",
        "label.padding_left=12", "label.padding_right=12",
        "click_script=" + shlex.quote(str(config / "plugins/quota.sh")) + " mode",
        "--set", anchor, "popup.drawing=on",
    ]
    sketchybar(*args)


def main():
    config = Path(os.environ["CONFIG_DIR"])
    state_dir = cache_dir() / "sketchybar"
    state_dir.mkdir(parents=True, exist_ok=True)
    # Focus events, polling and popup actions can overlap. Serialize only the
    # short cache-read/paint step, never the potentially slow provider fetch.
    with (state_dir / "quota-render.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        items = json.loads(sketchybar("--query", "bar"))["items"]
        # Hot reload clears the bar before rebuilding its widgets. Wait for our
        # anchor so an in-flight refresh cannot insert quotas at the far right.
        if "showy_quota.trigger" not in items:
            return
        mode = display_mode()
        action = sys.argv[1] if len(sys.argv) > 1 else "popup"
        if action == "mode":
            mode = "used" if mode == "remaining" else "remaining"
            (state_dir / "quota-mode").write_text(mode + "\n")
        metrics = read_metrics(config)
        if action in ("render", "mode"):
            render_strip(config, metrics, items, mode, close_popup=action == "mode")
        else:
            toggle_popup(config, metrics, items, mode)


if __name__ == "__main__":
    main()
