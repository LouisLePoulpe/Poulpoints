"""Minimal self-hosted sync demo. Put behind an HTTPS reverse proxy.

Set POULPOINTS_TOKEN to a long random value and POULPOINTS_DB to a writable path.
The API is intentionally single-account; do not expose without HTTPS.
"""
import hmac
import json
import os
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

TOKEN = os.environ.get('POULPOINTS_TOKEN', '')
DB = os.environ.get('POULPOINTS_DB', './poulpoints.sqlite3')
MAX_BYTES = 2_000_000


def merge(snapshot, incoming):
    """Deterministic last-writer-wins per task, with deletion tombstones."""
    tasks = {t['id']: t for t in snapshot.get('tasks', [])}
    deleted = {k: int(v) for k, v in snapshot.get('deleted', {}).items()}
    for k, v in incoming.get('deleted', {}).items():
        deleted[k] = max(deleted.get(k, 0), int(v))
    for task in incoming.get('tasks', []):
        key = task['id']
        previous = tasks.get(key)
        if previous is None or (int(task['updatedAt']), json.dumps(task, sort_keys=True)) > (
                int(previous.get('updatedAt', 0)), json.dumps(previous, sort_keys=True)):
            tasks[key] = task
    for key in list(tasks):
        if deleted.get(key, -1) >= int(tasks[key].get('updatedAt', 0)):
            del tasks[key]
    projects = sorted(set(snapshot.get('projects', [])) | set(incoming.get('projects', [])))
    return {'schemaVersion': 3, 'tasks': sorted(tasks.values(), key=lambda t: t['id']),
            'deleted': deleted, 'projects': projects}


def validate(data):
    if not isinstance(data, dict) or not isinstance(data.get('tasks'), list) or not isinstance(data.get('deleted'), dict) or not isinstance(data.get('projects'), list):
        raise ValueError('Invalid snapshot')
    if len(data['tasks']) > 10000 or len(data['projects']) > 1000 or len(data['deleted']) > 100000:
        raise ValueError('Too many items')
    for task in data['tasks']:
        if not isinstance(task, dict) or not isinstance(task.get('id'), str) or not task['id'] or len(task['id']) > 128 or not isinstance(task.get('updatedAt'), int):
            raise ValueError('Invalid task')
    if any(not isinstance(k, str) or not isinstance(v, int) for k, v in data['deleted'].items()):
        raise ValueError('Invalid deletion')
    if any(not isinstance(p, str) or not p.strip() for p in data['projects']):
        raise ValueError('Invalid project')


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/sync':
            self.send_error(404)
            return
        supplied = self.headers.get('Authorization', '')
        if not TOKEN or not hmac.compare_digest(supplied, 'Bearer ' + TOKEN):
            self.send_error(401)
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= MAX_BYTES:
                self.send_error(413)
                return
            incoming = json.loads(self.rfile.read(length))
            validate(incoming)
            with sqlite3.connect(DB, timeout=15) as conn:
                conn.execute('BEGIN IMMEDIATE')
                row = conn.execute('SELECT body FROM snapshot WHERE id = 1').fetchone()
                existing = json.loads(row[0]) if row else {'tasks': [], 'deleted': {}, 'projects': []}
                combined = merge(existing, incoming)
                conn.execute('INSERT INTO snapshot(id, body) VALUES(1, ?) ON CONFLICT(id) DO UPDATE SET body=excluded.body', (json.dumps(combined),))
                conn.commit()
            payload = json.dumps(combined).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except (ValueError, KeyError, TypeError, json.JSONDecodeError):
            self.send_error(400, 'Malformed snapshot')
        except sqlite3.Error:
            self.send_error(500, 'Database error')


def main():
    if len(TOKEN) < 32:
        raise SystemExit('POULPOINTS_TOKEN must contain at least 32 characters')
    Path(DB).parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(DB) as conn:
        conn.execute('CREATE TABLE IF NOT EXISTS snapshot (id INTEGER PRIMARY KEY, body TEXT NOT NULL)')
    host = os.environ.get('POULPOINTS_HOST', '127.0.0.1')
    port = int(os.environ.get('POULPOINTS_PORT', '8765'))
    print(f'Poulpoints sync listening on {host}:{port} (HTTP; place behind HTTPS reverse proxy)')
    ThreadingHTTPServer((host, port), Handler).serve_forever()


if __name__ == '__main__':
    main()
