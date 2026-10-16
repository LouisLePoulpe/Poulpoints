#!/usr/bin/env python3
"""Local companion: read-only projection, durable command queue, reminders.
Never opens Sembast or accesses cloud credentials. No network listener.
"""
import base64
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

ROOT = Path(os.environ.get("XDG_DATA_HOME", str(Path.home()/".local/share")))/"poulpoints-desktop"

def atomic(path, value):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    with temporary.open("x", encoding="utf-8") as stream:
        os.chmod(temporary, 0o600)
        json.dump(value, stream, ensure_ascii=False)
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)

def read_snapshot():
    try:
        with (ROOT/"snapshot.json").open(encoding="utf-8") as stream:
            data = json.load(stream)
        if data.get("version") != 1 or not isinstance(data.get("tasks"), list):
            raise ValueError("Unsupported projection")
        return data
    except FileNotFoundError:
        return {"tasks": [], "error": "Ouvrez Poulpoints une première fois."}

def enqueue(action, payload=None):
    if action not in ("complete", "new", "open-task"):
        raise ValueError("Unknown action")
    command = {"action": action}
    if action in ("complete", "open-task"):
        if not isinstance(payload, dict) or not all(isinstance(payload.get(k), str) for k in ("id", "revision")):
            raise ValueError("Invalid task")
        command.update(id=payload["id"], revision=payload["revision"])
    token = uuid.uuid4().hex
    atomic(ROOT/"commands"/(token+".json"), command)
    return token

def launch(background=False):
    launcher = ROOT/"launch.sh"
    if not launcher.is_file():
        raise RuntimeError("Compagnon non installé")
    subprocess.Popen([str(launcher)] + (["--background"] if background else []), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

def notify_due(snapshot, delivered, now_ms, notify):
    """Return successful deliveries only; failures are retried at next tick."""
    snapshot = {**snapshot, "tasks": [
        {**task, "remindAt": at}
        for task in snapshot["tasks"]
        for at in task.get("remindAts", [task.get("remindAt")])
        if at is not None
    ]}
    active = {str(t["id"])+":"+str(t.get("remindAt")) for t in snapshot["tasks"] if t.get("remindAt") is not None}
    sent = set(delivered) & active
    for task in snapshot["tasks"]:
        at = task.get("remindAt")
        key = str(task["id"])+":"+str(at)
        if isinstance(at, int) and now_ms-86400000 <= at <= now_ms and key not in sent:
            if notify(task):
                sent.add(key)
    return sent

def notify(task):
    # Argument array: titles and lists are never interpreted by a shell.
    import html
    result = subprocess.run(["notify-send", "--app-name=Poulpoints", "--icon="+str(ROOT/"logo.png"), "--", html.escape(task["title"]), html.escape(task["list"])], timeout=10, check=False)
    return result.returncode == 0

def watch():
    ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
    lock = (ROOT/"watch.lock").open("w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError:
        return
    state = ROOT/"delivered.json"
    try:
        delivered = set(json.loads(state.read_text()))
    except FileNotFoundError:
        delivered = set()
    while True:
        try:
            sent = notify_due(read_snapshot(), delivered, int(time.time()*1000), notify)
            if sent != delivered:
                atomic(state, sorted(sent))
                delivered = sent
        except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
            print(type(error).__name__ + ": rappel non envoyé, nouvelle tentative ultérieure", file=sys.stderr, flush=True)
        time.sleep(15)

def main():
    operation = sys.argv[1] if len(sys.argv)>1 else "read"
    if operation == "read": print(json.dumps(read_snapshot(), ensure_ascii=False))
    elif operation == "watch": watch()
    elif operation == "open": launch()
    elif operation == "new": enqueue("new"); launch()
    elif operation in ("complete", "open-task"):
        payload = json.loads(base64.b64decode(sys.argv[2], validate=True).decode("utf-8"))
        enqueue(operation,payload); launch(background=operation == "complete")
    else: raise ValueError("Unknown operation")

if __name__ == "__main__": main()
