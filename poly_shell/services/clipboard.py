"""Local clipboard history. Event-driven wl-paste watchers, owned by the shell."""
import hashlib
import ctypes
import json
import os
from pathlib import Path
import selectors
import signal
import sqlite3
import subprocess
import sys
import time

MAX_ITEM = 8 * 1024 * 1024
MAX_BYTES = 64 * 1024 * 1024
MAX_ITEMS = 200
MAX_PINS = 50


class History:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.images = self.directory / 'images'
        self.images.mkdir(exist_ok=True, mode=0o700)
        self.db = sqlite3.connect(self.directory / 'history.sqlite', timeout=10)
        self.db.row_factory = sqlite3.Row
        self.db.executescript('''
            CREATE TABLE IF NOT EXISTS clips (
                id TEXT PRIMARY KEY, mime TEXT NOT NULL, body BLOB NOT NULL,
                preview TEXT NOT NULL, updated REAL NOT NULL, pinned INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS preferences (key TEXT PRIMARY KEY, value INTEGER);
            INSERT OR IGNORE INTO preferences VALUES ('paused', 0);
        ''')

    @property
    def paused(self):
        return bool(self.db.execute("SELECT value FROM preferences WHERE key='paused'").fetchone()[0])

    def ingest(self, data, kind, state='data'):
        if state != 'data' or not data or len(data) > MAX_ITEM:
            return False
        if kind == 'image':
            if data.startswith(b'\x89PNG\r\n\x1a\n'): mime = 'image/png'
            elif data.startswith(b'\xff\xd8\xff'): mime = 'image/jpeg'
            elif data.startswith((b'GIF87a', b'GIF89a')): mime = 'image/gif'
            elif data.startswith(b'RIFF') and data[8:12] == b'WEBP': mime = 'image/webp'
            else: return False
            preview = 'Image · ' + mime.split('/')[1].upper()
        else:
            try: value = data.decode('utf-8')
            except UnicodeDecodeError: return False
            if not value.strip() or '\x00' in value: return False
            mime, preview = 'text/plain;charset=utf-8', value[:2000]
        ident = hashlib.sha256(mime.encode() + b'\0' + data).hexdigest()
        with self.db:
            # Serialize retention, pause and deduplication across both watchers.
            self.db.execute('BEGIN IMMEDIATE')
            if self.paused: return False
            pinned_bytes = self.db.execute('SELECT COALESCE(SUM(length(body)),0) FROM clips WHERE pinned=1 AND id!=?', (ident,)).fetchone()[0]
            if pinned_bytes + len(data) > MAX_BYTES: return False
            self.db.execute('''INSERT INTO clips(id,mime,body,preview,updated) VALUES(?,?,?,?,?)
                ON CONFLICT(id) DO UPDATE SET updated=excluded.updated''', (ident, mime, data, preview, time.time()))
            rows = self.db.execute('SELECT id,length(body) AS size,pinned FROM clips ORDER BY pinned DESC,updated DESC').fetchall()
            total = 0
            for index, row in enumerate(rows):
                total += row['size']
                if not row['pinned'] and (index >= MAX_ITEMS or total > MAX_BYTES):
                    self.db.execute('DELETE FROM clips WHERE id=?', (row['id'],))
        return True

    def snapshot(self):
        entries, keep = [], set()
        for row in self.db.execute('SELECT id,mime,preview,updated,pinned,length(body) AS size FROM clips ORDER BY pinned DESC,updated DESC'):
            item = dict(row)
            item['pinned'] = bool(item['pinned'])
            item['image'] = ''
            if row['mime'].startswith('image/'):
                filename = self.images / (row['id'] + '.' + row['mime'].split('/')[1])
                keep.add(filename.name)
                if not filename.exists():
                    data = self.db.execute('SELECT body FROM clips WHERE id=?', (row['id'],)).fetchone()[0]
                    filename.write_bytes(data)
                item['image'] = filename.as_uri()
            entries.append(item)
        for path in self.images.iterdir():
            if path.name not in keep: path.unlink()
        return {'entries': entries, 'paused': self.paused}

    def action(self, action, ident=''):
        if action == 'copy':
            row = self.db.execute('SELECT mime,body FROM clips WHERE id=?', (ident,)).fetchone()
            if not row: raise ValueError('Entry already deleted')
            subprocess.run(['wl-copy', '--type', row['mime']], input=row['body'], check=True, timeout=5)
        else:
            with self.db:
                self.db.execute('BEGIN IMMEDIATE')
                if action == 'pin':
                    row = self.db.execute('SELECT pinned FROM clips WHERE id=?', (ident,)).fetchone()
                    if not row: raise ValueError('Entry already deleted')
                    if not row['pinned'] and self.db.execute('SELECT COUNT(*) FROM clips WHERE pinned=1').fetchone()[0] >= MAX_PINS:
                        raise ValueError('Can pin up to 50 entries')
                    self.db.execute('UPDATE clips SET pinned=1-pinned WHERE id=?', (ident,))
                elif action == 'delete': self.db.execute('DELETE FROM clips WHERE id=?', (ident,))
                elif action == 'clear': self.db.execute('DELETE FROM clips WHERE pinned=0')
                elif action == 'pause': self.db.execute("UPDATE preferences SET value=1-value WHERE key='paused'")
                elif action != 'list': raise ValueError('Unknown action')


def directory():
    return Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'poly-shell/clipboard'


def serve(history):
    # One owner per session; hot reloads cannot leave duplicate collectors.
    import fcntl
    lock = (history.directory / 'collector.lock').open('w')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    watches = []
    parent_pid = os.getpid()
    def tie_to_parent():
        # Quickshell can SIGKILL a Process during hot reload. Linux must also
        # stop its data-control clients, even when our finally cannot run.
        if ctypes.CDLL(None).prctl(1, signal.SIGTERM, 0, 0, 0) != 0:
            os._exit(1)
        if os.getppid() != parent_pid:
            os._exit(1)
    selector = selectors.DefaultSelector()
    selector.register(sys.stdin, selectors.EVENT_READ, 'command')

    def emit(action='', error=''):
        print(json.dumps(dict(history.snapshot(), action=action, error=error), ensure_ascii=True), flush=True)

    def stop(_signum, _frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    try:
        for kind in ('text', 'image'):
            child = subprocess.Popen(['wl-paste', '--no-newline', '--type', kind, '--watch',
                sys.executable, str(Path(__file__).resolve()), 'ingest', kind],
                stdout=subprocess.PIPE, bufsize=0, preexec_fn=tie_to_parent)
            watches.append(child)
            selector.register(child.stdout, selectors.EVENT_READ, 'change')
        emit()
        while True:
            for key, _ in selector.select():
                line = key.fileobj.readline()
                if not line:
                    if key.data == 'command': return
                    raise RuntimeError('Clipboard service stopped')
                if key.data == 'change':
                    emit()
                    continue
                action = ''
                try:
                    request = json.loads(line)
                    action = request.get('action', '')
                    history.action(action, str(request.get('id', '')))
                    emit(action)
                except (ValueError, OSError, subprocess.SubprocessError, sqlite3.Error) as error:
                    emit('', str(error))
    finally:
        for child in watches:
            child.terminate()
        for child in watches:
            try: child.wait(timeout=2)
            except subprocess.TimeoutExpired: child.kill(); child.wait()
        selector.close()
        lock.close()


def main():
    os.umask(0o077)
    history = History(directory())
    try:
        if len(sys.argv) > 1 and sys.argv[1] == 'ingest':
            # Drain oversized inputs too, so the Wayland transfer can finish.
            data = sys.stdin.buffer.read(MAX_ITEM + 1)
            if len(data) > MAX_ITEM:
                while sys.stdin.buffer.read(65536): pass
                return
            if history.ingest(data, sys.argv[2], os.environ.get('CLIPBOARD_STATE', 'data')):
                print('changed', flush=True)
        else: serve(history)
    finally:
        history.db.close()


if __name__ == '__main__':
    try: main()
    except (OSError, ValueError, RuntimeError, sqlite3.Error) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
