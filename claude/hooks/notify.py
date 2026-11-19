#!/usr/bin/env python3
"""Desktop notification for Claude Code Stop/Notification hooks.

Names the herdr workspace, tab and session title so you can tell which
chat finished. Falls back to the cwd name outside herdr.
"""
import json
import os
import shlex
import shutil
import subprocess
import sys


def herdr(*args):
    try:
        out = subprocess.run(
            [os.environ.get("HERDR_BIN_PATH", "herdr"), *args],
            capture_output=True, text=True, timeout=2,
        ).stdout
        return json.loads(out).get("result", {})
    except Exception:
        return {}


def clip(text, n):
    text = " ".join(str(text or "").split())
    return text if len(text) <= n else text[: n - 1] + "…"


try:
    hook = json.load(sys.stdin)
except Exception:
    hook = {}

# Subagent stops are noise; only the main session matters.
if hook.get("agent_id") or hook.get("hook_event_name") == "SubagentStop":
    sys.exit(0)

event = hook.get("hook_event_name", "")
cwd = hook.get("cwd") or os.getcwd()
where = os.path.basename(cwd.rstrip("/"))
session = ""

if os.environ.get("HERDR_ENV") == "1" and os.environ.get("HERDR_PANE_ID"):
    pane = herdr("pane", "get", os.environ["HERDR_PANE_ID"]).get("pane", {})
    ws = herdr("workspace", "get", os.environ.get("HERDR_WORKSPACE_ID", "")).get("workspace", {})
    tab = herdr("tab", "get", os.environ.get("HERDR_TAB_ID", "")).get("tab", {})
    session = pane.get("terminal_title_stripped", "")
    parts = [ws.get("label")]
    if tab.get("label"):
        parts.append(f"tab {tab['label']}")
    where = " › ".join(p for p in parts if p) or where

if event == "Notification":
    status, sound = "needs input", "Ping"
    body = hook.get("message") or "Claude needs your input."
else:
    status, sound = "done", "Glass"
    body = hook.get("last_assistant_message") or "Finished."

title = f"Claude {status} · {clip(where, 40)}"
subtitle = clip(session, 60)
body = clip(body, 180)

notifier = shutil.which("terminal-notifier") or "/opt/homebrew/bin/terminal-notifier"
if os.path.exists(notifier):
    # Clicking brings Ghostty forward and focuses this session's herdr tab.
    cmd = [notifier, "-title", title, "-subtitle", subtitle, "-message", body,
           "-sound", sound, "-activate", "com.mitchellh.ghostty",
           "-group", os.environ.get("HERDR_PANE_ID", where)]
    tab_id = os.environ.get("HERDR_TAB_ID")
    if tab_id:
        herdr_bin = os.environ.get("HERDR_BIN_PATH", "herdr")
        cmd += ["-execute", f"{shlex.quote(herdr_bin)} tab focus {shlex.quote(tab_id)}"]
    sent = subprocess.run(cmd, capture_output=True, timeout=5).returncode == 0
else:
    sent = False

# Fallback when terminal-notifier is missing or macOS blocks it; clicks open Script Editor.
if not sent:
    script = (
        "on run argv\n"
        "display notification (item 3 of argv) with title (item 1 of argv) "
        "subtitle (item 2 of argv) sound name (item 4 of argv)\n"
        "end run"
    )
    subprocess.run(["osascript", "-e", script, title, subtitle, body, sound],
                   capture_output=True, timeout=5)
