from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import urlparse
from urllib.request import url2pathname

from poly_shell.clipboard import History


class ClipboardTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.history = History(self.directory)
        self.addCleanup(self.history.db.close)

    def entries(self):
        return self.history.snapshot()['entries']

    def test_exact_text_copy_deduplication_and_pin_survive_restart(self):
        data = 'Строка\n`$(literal)` <b>text</b>\n'.encode()
        self.assertTrue(self.history.ingest(data, 'text'))
        ident = self.entries()[0]['id']
        self.history.action('pin', ident)
        self.history.ingest(b'newer', 'text')
        self.history.ingest(data, 'text')
        self.assertEqual(len(self.entries()), 2)
        self.assertTrue(self.entries()[0]['pinned'])
        reopened = History(self.directory)
        self.addCleanup(reopened.db.close)
        self.assertTrue(reopened.snapshot()['entries'][0]['pinned'])
        with patch('poly_shell.clipboard.subprocess.run') as run:
            reopened.action('copy', ident)
            self.assertEqual(run.call_args.kwargs['input'], data)
            self.assertEqual(run.call_args.args[0], ['wl-copy', '--type', 'text/plain;charset=utf-8'])

    def test_pause_sensitive_empty_and_binary_text_do_not_enter_history(self):
        for state in ['sensitive', 'nil', 'clear']:
            self.assertFalse(self.history.ingest(b'secret', 'text', state))
        for data in [b'', b'\n ', b'\xff\xfe', b'a\x00b']:
            self.assertFalse(self.history.ingest(data, 'text'))
        self.history.action('pause')
        self.assertFalse(self.history.ingest(b'paused', 'text'))
        self.assertTrue(self.history.snapshot()['paused'])
        self.history.action('pause')
        self.assertTrue(self.history.ingest(b'resumed', 'text'))
        self.assertEqual(len(self.entries()), 1)

    def test_image_copy_is_lossless_and_deletion_removes_preview_file(self):
        data = b'\x89PNG\r\n\x1a\nexample'
        self.history.ingest(data, 'image')
        entry = self.entries()[0]
  
        preview = Path(url2pathname(urlparse(entry['image']).path))
        self.assertEqual(preview.read_bytes(), data)
        with patch('poly_shell.clipboard.subprocess.run') as run:
            self.history.action('copy', entry['id'])
            self.assertEqual(run.call_args.kwargs['input'], data)
            self.assertEqual(run.call_args.args[0][-1], 'image/png')
        self.history.action('delete', entry['id'])
        self.assertEqual(self.entries(), [])
        self.assertFalse(preview.exists())
        self.assertFalse(self.history.ingest(b'<svg/>', 'image'))

    def test_retention_and_clear_preserve_pins_and_byte_budget(self):
        self.history.ingest(b'pinned', 'text')
        self.history.action('pin', self.entries()[0]['id'])
        with patch('poly_shell.clipboard.MAX_ITEMS', 3), patch('poly_shell.clipboard.MAX_BYTES', 18):
            for text in [b'one', b'two', b'three', b'four', b'five']:
                self.history.ingest(text, 'text')
            self.assertLessEqual(len(self.entries()), 3)
            self.assertLessEqual(sum(e['size'] for e in self.entries()), 18)
            self.assertEqual(self.entries()[0]['preview'], 'pinned')
        self.history.action('clear')
        self.assertEqual([e['preview'] for e in self.entries()], ['pinned'])
        with self.assertRaises(ValueError): self.history.action('copy', 'missing')


if __name__ == '__main__': unittest.main()
