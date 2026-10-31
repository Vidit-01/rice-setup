#!/usr/bin/env python3
"""Run destructive session actions through the Codex CLI itself."""
import os
import shutil
import subprocess
import sys

from agents import load_attention_state, save_attention_state
from open_session import close_existing_session


HOME = os.path.expanduser("~")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("delete", "close"):
        raise RuntimeError("Usage: session_actions.py delete SESSION_UUID | close PROVIDER SESSION_ID")
    action = sys.argv[1]
    if action == "close":
        if len(sys.argv) != 4:
            raise RuntimeError("Usage: session_actions.py close PROVIDER SESSION_ID")
        provider, session_id = sys.argv[2:4]
        if not close_existing_session(provider, session_id):
            raise RuntimeError("Could not find the open terminal window for this chat.")
        return

    if len(sys.argv) != 3:
        raise RuntimeError("Usage: session_actions.py delete SESSION_UUID")
    session_id = sys.argv[2]
    if len(session_id) != 36 or not all(c in "0123456789abcdef-" for c in session_id.lower()):
        raise RuntimeError("Invalid Codex session ID.")
    codex = shutil.which("codex") or os.path.join(HOME, ".local", "bin", "codex")
    result = subprocess.run(
        [codex, "delete", session_id, "--force"],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout or "Codex could not delete this chat.").strip())
    state = load_attention_state()
    state["known"].pop(session_id, None)
    state["pending"].pop(session_id, None)
    save_attention_state(state)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
