#!/usr/bin/env python3
"""Show local Qwen activity without starting models or recording request content."""

import http.client
import json
import os
from pathlib import Path
import subprocess
from urllib.parse import urlencode


class Unavailable(Exception):
    """Local status is unavailable, without exposing responses or credentials."""


class Client:
    def __init__(self):
        try:
            settings = json.loads((Path.home() / ".omlx/settings.json").read_text())
        except FileNotFoundError as error:
            raise Unavailable("Not configured") from error
        self.port = settings.get("server", {}).get("port", 8000)
        if type(self.port) is not int or not 1 <= self.port <= 65535:
            raise ValueError("Invalid local port")
        self.key = settings.get("auth", {}).get("api_key", "")
        if not isinstance(self.key, str):
            raise ValueError("Invalid API key")

    def get(self, path):
        # Deliberately ignore bind host, proxy settings and redirects: credentials
        # must only reach the local oMLX listener, never a remote destination.
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=1.5)
        headers = {"Accept": "application/json"}
        if self.key:
            headers["Authorization"] = "Bearer " + self.key
        try:
            connection.request("GET", path, headers=headers)
            response = connection.getresponse()
            if response.status in (401, 403):
                raise Unavailable("Auth needed")
            if response.status != 200:
                raise Unavailable("Unavailable")
            return json.loads(response.read())
        except ConnectionRefusedError as error:
            raise Unavailable("Offline") from error
        except (OSError, http.client.HTTPException) as error:
            raise Unavailable("Unavailable") from error
        finally:
            connection.close()


def count(data, key):
    value = data[key]
    if type(value) is not int or value < 0:
        raise ValueError("Invalid counter")
    return value


def qwen_activity(data):
    models = data["active_models"]["models"]
    if not isinstance(models, list):
        raise ValueError("Invalid activity")
    qwen = []
    for model in models:
        if "qwen" in model["id"].lower():
            count(model, "active_requests")
            count(model, "waiting_requests")
            if type(model["is_loading"]) is not bool:
                raise ValueError("Invalid loading state")
            qwen.append(model)
    return qwen


def activity_label(models):
    active = sum(count(model, "active_requests") for model in models)
    waiting = sum(count(model, "waiting_requests") for model in models)
    if active:
        return f"{active} active", "ACCENT"
    if waiting:
        return f"{waiting} queued", "YELLOW"
    if any(model["is_loading"] for model in models):
        return "Loading", "YELLOW"
    return ("Idle", "GREEN") if models else ("Standby", "MUTED")


def compact(value):
    if value >= 1_000_000:
        return f"{value / 1_000_000:.1f}m"
    if value >= 1_000:
        return f"{value / 1_000:.1f}k"
    return str(value)


def details(client, models):
    if not models:
        return ["No Qwen model loaded", "Requests · none",
                "Tokens · unavailable", "Cached input · unavailable",
                "oMLX is online · models load on demand"]
    active = sum(count(model, "active_requests") for model in models)
    waiting = sum(count(model, "waiting_requests") for model in models)
    lines = [
        "Model · " + ", ".join(model["id"] for model in models),
        f"Requests · {active} active · {waiting} queued",
        "Tokens · unavailable",
        "Cached input · unavailable",
        "Qwen session · since server restart or stats reset",
    ]
    try:
        totals = dict.fromkeys(("total_prompt_tokens", "total_completion_tokens", "total_cached_tokens"), 0)
        for model in models:
            stats = client.get("/admin/api/stats?" + urlencode({"model": model["id"], "scope": "session"}))
            for key in totals:
                totals[key] += count(stats, key)
        lines[2] = (f"Tokens · {compact(totals['total_prompt_tokens'])} in"
                    f" · {compact(totals['total_completion_tokens'])} out")
        # Cached tokens are a subset of input, not additional usage.
        lines[3] = f"Cached input · {compact(totals['total_cached_tokens'])}"
    except (Unavailable, OSError, ValueError, KeyError, TypeError, AttributeError):
        pass  # Activity stays useful if the optional token endpoint fails.
    return lines


def sketchybar(*args):
    return subprocess.check_output(["sketchybar", *args], text=True)


def paint(label, color, lines):
    args = ["--set", "omlx", "drawing=on", "label=Qwen · " + label,
            "icon.color=" + os.environ[color]]
    for row, line in zip(("model", "requests", "tokens", "cached", "scope"), lines):
        args += ["--set", "omlx." + row, "label=" + line]
    sketchybar(*args)


def main():
    sender = os.environ.get("SENDER", "")
    if sender == "mouse.exited.global":
        sketchybar("--set", "omlx", "popup.drawing=off")
        return
    item = json.loads(sketchybar("--query", "omlx"))
    showing = item["popup"]["drawing"] in ("on", True)
    if sender in ("mouse.clicked", "omlx_toggle"):
        # A shortcut must not reveal a hidden, unavailable service. Polling
        # restores the item automatically when local activity responds again.
        if item["geometry"]["drawing"] not in ("on", True):
            return
        sketchybar("--set", "omlx", "popup.drawing=" + ("off" if showing else "on"))
        if showing:
            return
        showing = True

    try:
        client = Client()
        models = qwen_activity(client.get("/admin/api/activity"))
        label, color = activity_label(models)
        lines = details(client, models) if showing else []
    except (Unavailable, OSError, ValueError, KeyError, TypeError, AttributeError):
        sketchybar("--set", "omlx", "drawing=off", "popup.drawing=off")
        return
    paint(label, color, lines)


if __name__ == "__main__":
    main()
