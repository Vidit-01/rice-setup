#!/usr/bin/env python3
"""Summarize running, input-needed, and recently finished Codex sessions."""
import datetime as dt
import glob
import json
import os
import re
import sqlite3
import shutil
import sys
from urllib.parse import unquote, urlparse

CODEX = os.path.expanduser("~/.codex")
ATTENTION_FILE = os.path.expanduser("~/.local/share/agent-panel/attention.json")
RUNNING_MAX_AGE = 15 * 60
MAX_FINISHED = 50
CLAUDE_HOME = os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude"))
ANTIGRAVITY_HOME = os.path.expanduser("~/.gemini/antigravity-cli")


def clean(text):
    return re.sub(r"\s+", " ", text or "").strip()


def text_content(value):
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return " ".join(text_content(item) for item in value)
    if isinstance(value, dict):
        if value.get("type") in ("text", "input_text", "output_text"):
            return text_content(value.get("text", ""))
        return " ".join(text_content(v) for v in value.values() if isinstance(v, (str, list, dict)))
    return ""


def read_records(path):
    rows = []
    try:
        with open(path, encoding="utf-8") as stream:
            for line in stream:
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except (OSError, UnicodeError):
        pass
    return rows


def waiting_for_input(message):
    """Detect a direct question to the user in Codex's final turn message."""
    text = (message or "").lower()
    if "?" not in text:
        return False
    return bool(re.search(
        r"\b(which|what would you|what do you|where|when|would you prefer|"
        r"could you|can you|please (?:confirm|choose|share|tell)|"
        r"let me know which|what do you prefer|do you want)\b",
        text,
    ))


def detect_provider(metadata, title=""):
    hints = " ".join(str(metadata.get(key, "")) for key in (
        "model_provider", "originator", "thread_source", "source", "provider", "model"
    )) + " " + str(title)
    hints = hints.lower()
    if "claude" in hints or "anthropic" in hints:
        return "claude"
    if "cursor" in hints:
        return "cursor"
    if "gemini" in hints or "google" in hints:
        return "gemini"
    if "openai" in hints or "codex" in hints:
        return "openai"
    return "unknown"


def session_from_log(path, now):
    try:
        modified = os.path.getmtime(path)
    except OSError:
        return None
    rows = read_records(path)
    if not rows:
        return None

    session_id = ""
    cwd = ""
    active = False
    final_message = ""
    current_summary = ""
    completed_turn = ""
    completed_at = modified
    metadata = {}
    for row in rows:
        kind = row.get("type")
        payload = row.get("payload", {})
        if kind == "session_meta":
            session_id = payload.get("session_id", payload.get("id", session_id))
            cwd = payload.get("cwd", cwd)
            metadata = payload
        elif kind == "event_msg":
            event = payload.get("type")
            if event == "task_started":
                active = True
                final_message = ""
            elif event == "task_complete":
                active = False
                final_message = clean(payload.get("last_agent_message", ""))
                completed_turn = payload.get("turn_id", "")
                completed_at = payload.get("completed_at", payload.get("completed_at_ms", modified))
                if completed_at > 10_000_000_000:
                    completed_at /= 1000
            elif event == "item_completed":
                item = payload.get("item", {})
                if item.get("type") == "UserMessage":
                    active = True
                    final_message = ""
                    prompt = clean(text_content(item.get("content", [])))
                    if prompt:
                        current_summary = prompt
                elif item.get("type") == "AgentMessage":
                    answer = clean(text_content(item.get("content", [])))
                    if answer:
                        current_summary = answer
        elif kind == "response_item":
            item_type = payload.get("type")
            if item_type == "message" and payload.get("role") == "assistant":
                message = clean(text_content(payload.get("content", [])))
                if message:
                    current_summary = message
            elif item_type in ("custom_tool_call", "function_call"):
                current_summary = "Working with a tool…"

    if not session_id:
        return None
    age_seconds = max(0, now - modified)
    is_running = active and age_seconds <= RUNNING_MAX_AGE
    summary = final_message if not is_running and final_message else current_summary
    summary = (summary or ("Working…" if is_running else "Turn finished"))[:240]
    age = int(age_seconds)
    age_label = f"{age}s ago" if age < 60 else f"{age // 60}m ago" if age < 3600 else f"{age // 3600}h ago"
    return {
        "id": session_id,
        "project": os.path.basename(cwd.rstrip("/")) or "Codex",
        "projectPath": cwd or "",
        "summary": summary,
        "updated": modified,
        "age": age_label,
        "active": is_running,
        "needsInput": not is_running and waiting_for_input(final_message),
        "completedTurn": completed_turn,
        "completedAt": completed_at,
        "provider": detect_provider(metadata),
        "sourceApp": "codex",
        "canDelete": True,
    }


def display_time(seconds):
    age = max(0, int(seconds))
    return f"{age}s ago" if age < 60 else f"{age // 60}m ago" if age < 3600 else f"{age // 3600}h ago"


def session_record(session_id, provider, source_app, project_path, name, summary,
                   modified, now, active=False, needs_input=False, completed_at=None,
                   can_open=True):
    age_seconds = max(0, now - modified)
    active = bool(active and age_seconds <= RUNNING_MAX_AGE)
    return {
        "id": str(session_id), "project": os.path.basename(project_path.rstrip("/")) or name or source_app,
        "projectPath": project_path or "", "summary": clean(summary)[:240] or "No summary available",
        "updated": modified, "age": display_time(age_seconds), "active": active,
        "needsInput": bool(needs_input and not active), "completedTurn": str(int(modified)),
        "completedAt": completed_at or modified, "provider": provider, "sourceApp": source_app,
        "name": clean(name) or (clean(summary)[:72] or os.path.basename(project_path.rstrip("/")) or source_app),
        "canOpen": can_open, "canDelete": False,
    }


def open_agent_sessions():
    """Map provider/session pairs to processes still attached to a terminal."""
    provider_flags = {
        "openai": ("codex", "resume"),
        "claude": ("claude", "--resume"),
        "gemini": ("agy", "--conversation"),
    }
    terminal_names = {
        "ghostty", "konsole", "kitty", "alacritty", "wezterm", "foot",
        "xterm", "tilix", "gnome-terminal-server", "kgx", "ptyxis",
        "xfce4-terminal", "mate-terminal",
    }
    processes = {}
    for entry in os.scandir("/proc"):
        if not entry.name.isdigit():
            continue
        try:
            with open(os.path.join(entry.path, "stat"), encoding="utf-8") as stream:
                stat = stream.read()
            fields = stat[stat.rfind(")") + 2:].split()
            parent_pid = int(fields[1])
            with open(os.path.join(entry.path, "cmdline"), "rb") as stream:
                argv = [part.decode(errors="replace") for part in stream.read().split(b"\0") if part]
        except OSError:
            continue
        except (ValueError, IndexError):
            continue
        try:
            executable = os.path.basename(os.readlink(os.path.join(entry.path, "exe"))).lower()
        except OSError:
            executable = ""
        names = {os.path.basename(value).lower() for value in argv}
        environment = {}
        try:
            with open(os.path.join(entry.path, "environ"), "rb") as stream:
                for item in stream.read().split(b"\0"):
                    if b"=" in item:
                        key, value = item.split(b"=", 1)
                        environment[key.decode(errors="replace")] = value.decode(errors="replace")
        except OSError:
            pass
        processes[int(entry.name)] = (parent_pid, argv, names, executable, environment)

    def has_terminal_ancestor(process_id):
        seen = set()
        current = process_id
        while current > 1 and current not in seen:
            seen.add(current)
            process = processes.get(current)
            if not process:
                return False
            parent_pid, _, names, executable, _ = process
            if executable in terminal_names or names.intersection(terminal_names):
                return True
            current = parent_pid
        return False

    found = {}
    for process_id, (_, argv, names, _, environment) in processes.items():
        args = argv[1:]
        provider = environment.get("AGENT_PANEL_PROVIDER", "")
        session_id = environment.get("AGENT_PANEL_SESSION_ID", "")
        if provider and session_id and has_terminal_ancestor(process_id):
            found.setdefault((provider, session_id), set()).add(process_id)

        # Older sessions lack the Agent Panel environment markers; recognize
        # their provider CLI arguments, but only while they're in a terminal.
        for provider, (command_name, resume_flag) in provider_flags.items():
            if command_name in names and resume_flag in args and has_terminal_ancestor(process_id):
                try:
                    session_id = args[args.index(resume_flag) + 1]
                except IndexError:
                    continue
                found.setdefault((provider, session_id), set()).add(process_id)
    return found


def claude_sessions(now):
    """Read Claude Code's project JSONL transcripts without modifying them."""
    found = {}
    for path in glob.glob(os.path.join(CLAUDE_HOME, "projects", "**", "*.jsonl"), recursive=True):
        rows = read_records(path)
        if not rows:
            continue
        session_id = rows[0].get("sessionId") or rows[0].get("session_id") or os.path.splitext(os.path.basename(path))[0]
        cwd = next((row.get("cwd") for row in rows if row.get("cwd")), "")
        messages = []
        for row in rows:
            message = row.get("message", {})
            role = row.get("type") or message.get("role", "")
            body = clean(text_content(message.get("content", row.get("content", ""))))
            if role in ("user", "assistant") and body:
                messages.append((role, body, row))
        if not messages:
            continue
        last_role, last_text, last_row = messages[-1]
        try:
            modified = os.path.getmtime(path)
        except OSError:
            continue
        stop_reason = last_row.get("message", {}).get("stop_reason")
        active = last_role == "user" or (last_role == "assistant" and stop_reason not in ("end_turn", "stop_sequence"))
        final = next((body for role, body, _ in reversed(messages) if role == "assistant"), last_text)
        needs_input = not active and waiting_for_input(final)
        title = next((body for role, body, _ in messages if role == "user"), "")
        item = session_record(session_id, "claude", "claude", cwd, title, last_text if active else final,
                              modified, now, active, needs_input, modified)
        item["name"] = title[:72] or item["project"]
        item["canOpen"] = bool(shutil.which("claude") or os.path.isfile(os.path.expanduser("~/.local/bin/claude")))
        found[item["id"]] = item
    return found


def file_uri_path(uri):
    if not uri:
        return ""
    parsed = urlparse(uri)
    return unquote(parsed.path) if parsed.scheme == "file" else uri


def antigravity_sessions(now):
    """Antigravity CLI exposes its local conversation index in SQLite."""
    path = os.path.join(ANTIGRAVITY_HOME, "conversation_summaries.db")
    found = {}
    try:
        db = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=0.2)
        db.row_factory = sqlite3.Row
        rows = db.execute("SELECT conversation_id,title,preview,last_modified_time,workspace_uris,status,not_fully_idle,killed,app_data_dir FROM conversation_summaries").fetchall()
        db.close()
    except (OSError, sqlite3.Error):
        return found
    for row in rows:
        try:
            modified = dt.datetime.fromisoformat(str(row["last_modified_time"]).replace("Z", "+00:00")).timestamp()
        except (ValueError, TypeError):
            continue
        workspace = row["workspace_uris"] or ""
        try:
            uris = json.loads(workspace)
            if isinstance(uris, list):
                workspace = next(iter(uris), "")
            elif isinstance(uris, dict):
                workspace = uris.get("uri") or uris.get("workspaceUri") or uris.get("path") or ""
            else:
                workspace = uris
        except (json.JSONDecodeError, TypeError):
            pass
        project_path = file_uri_path(str(workspace))
        recent = now - modified <= RUNNING_MAX_AGE
        busy = bool(row["not_fully_idle"] and not row["killed"] and recent)
        item = session_record(row["conversation_id"], "gemini", "antigravity", project_path,
                              row["title"], row["preview"], modified, now, busy,
                              str(row["status"]).lower() in ("waiting", "needs_input"), modified,
                              can_open=bool(shutil.which("agy")))
        item["name"] = clean(row["title"]) or item["project"]
        found[item["id"]] = item
    # The IDE writes one transcript per conversation in its documented brain store.
    ide_brain = os.path.expanduser("~/.gemini/antigravity-ide/brain")
    for transcript in glob.glob(os.path.join(ide_brain, "*", ".system_generated", "logs", "transcript.jsonl")):
        log = read_records(transcript)
        if not log:
            continue
        messages = []
        cwd = ""
        for row in log:
            cwd = row.get("workspace", row.get("cwd", cwd))
            role = str(row.get("role") or row.get("type") or row.get("speaker") or "").lower()
            body = clean(text_content(row.get("content", row.get("message", row.get("text", "")))))
            if role in ("user", "assistant", "human", "model") and body:
                messages.append(("user" if role in ("user", "human") else "assistant", body, row))
        if not messages:
            continue
        try:
            modified = os.path.getmtime(transcript)
        except OSError:
            continue
        role, summary, last = messages[-1]
        active = role == "user" or (role == "assistant" and last.get("finished") is False)
        final = next((body for who, body, _ in reversed(messages) if who == "assistant"), summary)
        sid = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(transcript))))
        cwd = file_uri_path(str(cwd))
        title = next((body for who, body, _ in messages if who == "user"), "Antigravity task")
        item = session_record(sid, "gemini", "antigravity", cwd, title,
                              summary if active else final, modified, now, active,
                              not active and waiting_for_input(final), modified, can_open=False)
        item["name"] = title[:72]
        found[item["id"]] = item
    return found


def cursor_sessions(now):
    """Best-effort read of Cursor's local SQLite composer index, if installed."""
    config = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    paths = [os.path.join(config, "Cursor", "User", "globalStorage", "state.vscdb")]
    paths.extend(glob.glob(os.path.join(config, "Cursor", "User", "workspaceStorage", "*", "state.vscdb")))
    found = {}
    for db_path in paths:
        if not os.path.isfile(db_path):
            continue
        try:
            db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=0.2)
            table = db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='ItemTable'").fetchone()
            if not table:
                db.close()
                continue
            entries = db.execute("SELECT key,value FROM ItemTable WHERE key LIKE '%composer%' OR key LIKE '%Composer%'").fetchall()
            db.close()
        except sqlite3.Error:
            continue
        workspace_path = ""
        workspace_file = os.path.join(os.path.dirname(db_path), "workspace.json")
        try:
            workspace = json.load(open(workspace_file, encoding="utf-8"))
            workspace_path = file_uri_path(workspace.get("folder", {}).get("uri", ""))
        except (OSError, ValueError, AttributeError):
            pass
        for key, raw in entries:
            try:
                data = json.loads(raw)
            except (TypeError, json.JSONDecodeError):
                continue
            composers = data.get("allComposers", data.get("composers", [])) if isinstance(data, dict) else []
            if isinstance(composers, dict):
                composers = list(composers.values())
            if not isinstance(composers, list):
                continue
            for chat in composers:
                if not isinstance(chat, dict):
                    continue
                sid = chat.get("composerId") or chat.get("id")
                if not sid:
                    continue
                stamp = chat.get("lastUpdatedAt") or chat.get("updatedAt") or chat.get("createdAt") or 0
                try:
                    stamp = float(stamp) / (1000 if float(stamp) > 10_000_000_000 else 1)
                except (TypeError, ValueError):
                    stamp = os.path.getmtime(db_path)
                title = clean(chat.get("name") or chat.get("title") or chat.get("subtitle")) or "Cursor chat"
                activity = clean(chat.get("lastMessage") or chat.get("summary") or title)
                active = bool(chat.get("isGenerating") or chat.get("isRunning"))
                item = session_record(sid, "cursor", "cursor", workspace_path, title, activity,
                                      stamp, now, active, False, stamp, can_open=bool(shutil.which("cursor")))
                item["name"] = title
                item["canOpen"] = bool(shutil.which("cursor"))
                found[item["id"]] = item
    return found


def load_attention_state():
    try:
        with open(ATTENTION_FILE, encoding="utf-8") as stream:
            state = json.load(stream)
        return {
            "initialized": bool(state.get("initialized")),
            "known": state.get("known", {}),
            "pending": state.get("pending", {}),
        }
    except (OSError, json.JSONDecodeError, AttributeError):
        return {"initialized": False, "known": {}, "pending": {}}


def save_attention_state(state):
    os.makedirs(os.path.dirname(ATTENTION_FILE), exist_ok=True)
    temporary = ATTENTION_FILE + ".tmp"
    with open(temporary, "w", encoding="utf-8") as stream:
        json.dump(state, stream)
    os.replace(temporary, ATTENTION_FILE)


def acknowledge_session(session_id):
    state = load_attention_state()
    sessions = collect_sessions(dt.datetime.now().timestamp())
    item = next((agent for agent in sessions.values() if agent["id"] == session_id), None)
    if item and item["completedTurn"]:
        state["known"][session_id] = item["completedTurn"]
    state["pending"].pop(session_id, None)
    state["initialized"] = True
    save_attention_state(state)


def acknowledge_all_sessions():
    """Mark each currently finished turn as seen and clear its new indicator."""
    state = load_attention_state()
    for key, item in collect_sessions(dt.datetime.now().timestamp()).items():
        turn = item.get("completedTurn")
        if turn and not item.get("active"):
            state["known"][key] = turn
        state["pending"].pop(key, None)
    state["initialized"] = True
    save_attention_state(state)


def collect_sessions(now):
    by_id = {}
    pattern = os.path.join(CODEX, "sessions", "**", "rollout-*.jsonl")
    for path in glob.glob(pattern, recursive=True):
        item = session_from_log(path, now)
        if item and (item["id"] not in by_id or item["updated"] > by_id[item["id"]]["updated"]):
            by_id[item["id"]] = item

    for collection in (claude_sessions(now), cursor_sessions(now), antigravity_sessions(now)):
        for session_id, item in collection.items():
            key = item["sourceApp"] + ":" + session_id
            item["attentionKey"] = key
            by_id[key] = item

    index = {}
    for row in read_records(os.path.join(CODEX, "session_index.jsonl")):
        session_id = row.get("id")
        if session_id:
            index[session_id] = row
    for session_id, item in by_id.items():
        indexed = index.get(item["id"], {}) if item.get("sourceApp") == "codex" else {}
        item["name"] = indexed.get("thread_name") or item["project"]
        if item["provider"] == "unknown":
            item["provider"] = detect_provider(item, item["name"])
        updated = indexed.get("updated_at")
        if updated:
            try:
                parsed = dt.datetime.fromisoformat(updated.replace("Z", "+00:00"))
                item["updated"] = parsed.timestamp()
            except (ValueError, TypeError):
                pass
    open_sessions = open_agent_sessions()
    for item in by_id.values():
        item["opened"] = (item["provider"], str(item["id"])) in open_sessions
    return by_id


def main():
    now = dt.datetime.now().timestamp()
    by_id = collect_sessions(now)
    state = load_attention_state()
    if len(sys.argv) > 1 and sys.argv[1] == "acknowledge":
        if len(sys.argv) > 2:
            acknowledge_session(sys.argv[2])
        return
    if len(sys.argv) > 1 and sys.argv[1] == "acknowledge-all":
        acknowledge_all_sessions()
        return

    if not state["initialized"]:
        # On first install, surface recent completions so already-open agent
        # windows do not get silently missed. Older history starts as seen.
        for session_id, item in by_id.items():
            turn = item["completedTurn"]
            if not turn or item["active"]:
                continue
            if now - item["completedAt"] <= 24 * 3600:
                state["pending"][session_id] = turn
            else:
                state["known"][session_id] = turn
        state["initialized"] = True
    else:
        for session_id, item in by_id.items():
            turn = item["completedTurn"]
            if turn and not item["active"] and state["known"].get(session_id) != turn:
                if item.get("sourceApp") == "codex" or now - item["completedAt"] <= 24 * 3600:
                    state["pending"][session_id] = turn
                else:
                    state["pending"].pop(session_id, None)
                state["known"][session_id] = turn

    running, waiting, finished = [], [], []
    for session_id, item in by_id.items():
        item["attention"] = state["pending"].get(session_id) == item["completedTurn"] and not item["needsInput"]
        if item["active"]:
            item["status"] = "Running"
            running.append(item)
        elif item["needsInput"]:
            item["status"] = "Needs input"
            waiting.append(item)
        else:
            item["status"] = "Finished"
            finished.append(item)

    running.sort(key=lambda item: (not item["opened"], -item["updated"]))
    waiting.sort(key=lambda item: (not item["opened"], -item["updated"]))
    finished.sort(key=lambda item: (not item["opened"], -item["completedAt"], -item["updated"]))
    attention_count = sum(1 for item in finished if item["attention"])
    featured = None
    opened = running + waiting + finished
    if any(item["opened"] for item in opened):
        opened = [item for item in opened if item["opened"]]
        priority = {"Running": 0, "Needs input": 1, "Finished": 2}
        opened.sort(key=lambda item: (
            priority[item["status"]],
            -item["updated" if item["status"] != "Finished" else "completedAt"],
        ))
        item = opened[0]
        display_status = "Last done" if item["status"] == "Finished" else item["status"]
        featured = dict(item, displayStatus=display_status)
    elif running:
        featured = dict(running[0], displayStatus="Running")
    elif finished:
        featured = dict(finished[0], displayStatus="Last done")
    elif waiting:
        featured = dict(waiting[0], displayStatus="Needs input")
    result = {
        "running": running,
        "waiting": waiting,
        "finished": finished[:MAX_FINISHED],
        "attention": attention_count,
        "featured": featured,
    }
    save_attention_state(state)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
