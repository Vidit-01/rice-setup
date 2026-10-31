#!/usr/bin/env python3
"""Open an agent session in the terminal selected in KDE System Settings."""
import configparser
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import uuid

from agents import acknowledge_session, open_agent_sessions


HOME = os.path.expanduser("~")


def kde_terminal():
    settings = configparser.ConfigParser(interpolation=None)
    settings.optionxform = str
    settings.read(os.path.join(HOME, ".config", "kdeglobals"), encoding="utf-8")
    terminal_command = settings.get("General", "TerminalApplication", fallback="").strip()
    service = settings.get("General", "TerminalService", fallback="").strip()
    if not terminal_command:
        raise RuntimeError("Set a default terminal in KDE System Settings → Apps → Default Applications.")

    terminal_exec_arg = "-e"
    desktop_id = service if service.endswith(".desktop") else service + ".desktop"
    data_dirs = [os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local", "share"))]
    data_dirs.extend(os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"))
    for data_dir in data_dirs:
        candidate = os.path.join(data_dir, "applications", desktop_id)
        if not os.path.isfile(candidate):
            continue
        desktop = configparser.ConfigParser(interpolation=None)
        desktop.optionxform = str
        desktop.read(candidate, encoding="utf-8")
        terminal_exec_arg = desktop.get("Desktop Entry", "X-TerminalArgExec", fallback="-e").strip()
        break
    return shlex.split(terminal_command) + shlex.split(terminal_exec_arg)


def terminal_window_ids():
    """Return KWin app identifiers for the configured default terminal."""
    settings = configparser.ConfigParser(interpolation=None)
    settings.optionxform = str
    settings.read(os.path.join(HOME, ".config", "kdeglobals"), encoding="utf-8")
    terminal_command = shlex.split(settings.get("General", "TerminalApplication", fallback="").strip())
    service = settings.get("General", "TerminalService", fallback="").strip()
    identifiers = set()
    if service:
        identifiers.add(service.removesuffix(".desktop").lower())
    if terminal_command:
        identifiers.add(os.path.basename(terminal_command[0]).lower())
    return sorted(identifiers)


def proc_info(pid):
    """Return (parent pid, command line, executable name, environment) for a live process."""
    try:
        with open("/proc/%s/stat" % pid, encoding="utf-8") as stream:
            stat = stream.read()
        fields = stat[stat.rfind(")") + 2:].split()
        parent_pid = int(fields[1])
        with open("/proc/%s/cmdline" % pid, "rb") as stream:
            argv = [part.decode(errors="replace") for part in stream.read().split(b"\0") if part]
        environment = {}
        try:
            with open("/proc/%s/environ" % pid, "rb") as stream:
                for item in stream.read().split(b"\0"):
                    if b"=" in item:
                        key, value = item.split(b"=", 1)
                        environment[key.decode(errors="replace")] = value.decode(errors="replace")
        except OSError:
            pass
        executable = os.path.basename(os.readlink("/proc/%s/exe" % pid))
        return parent_pid, argv, executable, environment
    except (OSError, ValueError, IndexError):
        return None


def matching_session_processes(provider, session_id):
    """Find running CLI processes for this exact provider session."""
    return sorted(open_agent_sessions().get((provider, str(session_id)), set()))


def terminal_ancestors(process_ids):
    """Collect terminal process IDs above matching CLI processes."""
    terminal_names = {
        "ghostty", "konsole", "kitty", "alacritty", "wezterm", "foot",
        "xterm", "tilix", "gnome-terminal-server", "kgx", "ptyxis",
        "xfce4-terminal", "mate-terminal",
    }
    result = set()
    for process_id in process_ids:
        seen = set()
        current = process_id
        while current > 1 and current not in seen:
            seen.add(current)
            info = proc_info(current)
            if not info:
                break
            parent_pid, argv, executable, _ = info
            command_names = {os.path.basename(value).lower() for value in argv}
            if executable.lower() in terminal_names or command_names.intersection(terminal_names):
                result.add(current)
            current = parent_pid
    return result


def control_window_with_kwin(window_title, process_ids, app_ids, action):
    """Ask KWin to focus or close a window selected by title or process."""
    qdbus = shutil.which("qdbus6") or shutil.which("qdbus")
    if not qdbus:
        return False

    plugin_name = "agentpanel_focus_%s" % uuid.uuid4().hex
    script = """
var marker = %s;
var pids = %s;
var appIds = %s;
var action = %s;
var windows = workspace.stackingOrder;
var target = null;
for (var i = windows.length - 1; i >= 0; --i) {
    if (windows[i].caption.indexOf(marker) !== -1) { target = windows[i]; break; }
}
if (!target) {
    for (var j = windows.length - 1; j >= 0; --j) {
        if (pids.indexOf(windows[j].pid) !== -1) { target = windows[j]; break; }
    }
}
if (!target) {
    for (var k = windows.length - 1; k >= 0; --k) {
        var desktopId = String(windows[k].desktopFileName || "").toLowerCase();
        var resourceClass = String(windows[k].resourceClass || "").toLowerCase();
        if (appIds.some(function (id) { return desktopId === id || resourceClass === id; })) {
            target = windows[k];
            break;
        }
    }
}
if (target) {
    if (action === "close") {
        target.closeWindow();
    } else {
        if (target.desktops && target.desktops.length > 0
                && target.desktops.indexOf(workspace.currentDesktop) === -1) {
            workspace.currentDesktop = target.desktops[0];
        }
        target.minimized = false;
        workspace.activateWindow(target);
    }
}
""" % (
        json_string(window_title), json_array(sorted(process_ids)),
        json_array(app_ids), json_string(action),
    )

    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".js", encoding="utf-8", delete=False) as stream:
            stream.write(script)
            script_path = stream.name
        loaded = subprocess.run(
            [qdbus, "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.loadScript", script_path, plugin_name],
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            text=True, timeout=2, check=True,
        )
        script_id = loaded.stdout.strip()
        if not script_id.isdigit():
            return False
        subprocess.run(
            [qdbus, "org.kde.KWin", "/Scripting/Script%s" % script_id, "org.kde.kwin.Script.run"],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            timeout=2, check=True,
        )
        return True
    except (OSError, subprocess.SubprocessError):
        return False
    finally:
        try:
            subprocess.run(
                [qdbus, "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.unloadScript", plugin_name],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                timeout=2, check=False,
            )
        except (OSError, subprocess.SubprocessError):
            pass
        if "script_path" in locals():
            try:
                os.unlink(script_path)
            except OSError:
                pass


def json_string(value):
    return json.dumps(value)


def json_array(values):
    return json.dumps(values)


def focus_existing_session(provider, session_id):
    process_ids = matching_session_processes(provider, session_id)
    if not process_ids:
        return False
    title = "Agent Panel · %s · %s" % (provider, session_id)
    return control_window_with_kwin(title, terminal_ancestors(process_ids), terminal_window_ids(), "focus")


def close_existing_session(provider, session_id):
    process_ids = matching_session_processes(provider, session_id)
    if not process_ids:
        return False
    title = "Agent Panel · %s · %s" % (provider, session_id)
    # Prefer the exact title, then the terminal process that owns the session.
    return control_window_with_kwin(title, terminal_ancestors(process_ids), [], "close")


def main():
    if len(sys.argv) != 4:
        raise RuntimeError("Expected provider, session ID, and project path.")
    provider, session_id, project_path = sys.argv[1:4]
    if not session_id or any(ord(c) < 32 or ord(c) == 127 for c in session_id):
        raise RuntimeError("Invalid session ID.")
    if focus_existing_session(provider, session_id):
        if provider == "openai":
            acknowledge_session(session_id)
        return
    if provider == "openai":
        executable = shutil.which("codex") or os.path.join(HOME, ".local", "bin", "codex")
        args = ["resume", session_id]
    elif provider == "claude":
        executable = shutil.which("claude") or os.path.join(HOME, ".local", "bin", "claude")
        args = ["--resume", session_id]
    elif provider == "gemini":
        executable = shutil.which("agy") or os.path.join(HOME, ".local", "bin", "agy")
        args = ["--conversation", session_id]
    elif provider == "cursor":
        executable = shutil.which("cursor")
        args = [project_path] if project_path else []
        if not args:
            raise RuntimeError("Cursor sessions can be identified, but Cursor has no supported command here to resume a specific chat.")
    else:
        raise RuntimeError("This agent provider cannot be opened yet.")
    if not executable or not os.path.isfile(executable):
        raise RuntimeError("Could not find the %s CLI." % provider)
    title = "Agent Panel · %s · %s" % (provider, session_id)
    launch_command = [
        "/bin/sh", "-c",
        'title=$1; provider=$2; session_id=$3; shift 3; '
        'export AGENT_PANEL_PROVIDER="$provider" AGENT_PANEL_SESSION_ID="$session_id"; '
        'printf "\\033]2;%s\\007" "$title"; exec "$@"',
        "agent-panel-session", title, provider, session_id, executable, *args,
    ]
    command = kde_terminal() + launch_command
    cwd = project_path if project_path and os.path.isdir(project_path) else None
    subprocess.Popen(
        command,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True,
        start_new_session=True,
        cwd=cwd,
    )
    if provider == "openai":
        acknowledge_session(session_id)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
