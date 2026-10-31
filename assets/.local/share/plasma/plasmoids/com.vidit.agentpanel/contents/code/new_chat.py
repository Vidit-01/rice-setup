#!/usr/bin/env python3
"""Launch a fresh Codex chat in a selected project directory."""
import os
import shutil
import subprocess
import sys

from open_session import kde_terminal


HOME = os.path.expanduser("~")


def main():
    if len(sys.argv) != 2:
        raise RuntimeError("Choose a project directory for the new chat.")
    project = os.path.abspath(os.path.expanduser(sys.argv[1]))
    if not os.path.isdir(project):
        raise RuntimeError("That project directory does not exist.")
    codex = shutil.which("codex") or os.path.join(HOME, ".local", "bin", "codex")
    if not os.path.isfile(codex):
        raise RuntimeError("Could not find the Codex CLI.")
    subprocess.Popen(
        kde_terminal() + [codex, "--cd", project],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True,
        start_new_session=True,
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
