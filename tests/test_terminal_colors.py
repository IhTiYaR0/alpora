"""Saved/live terminal palettes agree without sending input to running shells."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from poly_shell import terminal_colors as terminal, themes
from poly_shell.state import ConfigError


PALETTE = {'background': '#172239', 'surface': '#26364b', 'text': '#edf0f4',
           'muted': '#a3adb7', 'accent': '#8aace0', 'secondary': '#c5a4d8',
           'cool': '#83c3d1', 'border': '#445566'}


class TerminalColorsTests(unittest.TestCase):
    def test_all_ansi_colors_and_sections_change_without_losing_preferences(self):
        with tempfile.TemporaryDirectory() as folder:
            config = Path(folder)
            foot = config/'foot/foot.ini'; foot.parent.mkdir()
            foot.write_text('[main]\nfont=My Font:size=13\n[colors-dark]\nalpha=0.92\nregular1=aaaaaa\n[colors-light]\nalpha=1.0\nbackground=ffffff\n[key-bindings]\ncopy=Control+c\n')
            kitty = config/'kitty/kitty.conf'; kitty.parent.mkdir()
            kitty.write_text('font_size 17\ninclude custom.conf\nbackground #ffffff\n')
            files = terminal.config_files(config, PALETTE)
            text = files[foot]
            self.assertIn('font=My Font:size=13', text)
            self.assertIn('copy=Control+c', text)
            self.assertIn('alpha=0.92', text); self.assertIn('alpha=1.0', text)
            for i, color in enumerate(terminal.colors(PALETTE)):
                key = ('regular' if i < 8 else 'bright')+str(i % 8)
                self.assertEqual(text.count(key+'='+color[1:]), 2)
                self.assertIn('color'+str(i)+' '+color, files[kitty])
            self.assertGreater(files[kitty].index('background #172239'), files[kitty].index('include custom.conf'))
            for path, text in files.items(): path.write_text(text)
            self.assertEqual(files, terminal.config_files(config, PALETTE))

    def test_discovery_only_accepts_supported_emulator_masters(self):
        with tempfile.TemporaryDirectory() as folder:
            proc = Path(folder)
            for pid, name in ((1, 'foot'), (2, 'kitty'), (3, 'zsh')):
                root = proc/str(pid); (root/'fdinfo').mkdir(parents=True)
                (root/'comm').write_text(name+'\n')
                (root/'fdinfo/4').write_text('tty-index:\t'+str(pid)+'\n')
            self.assertEqual(terminal.terminal_ptys(proc), [Path('/dev/pts/1'), Path('/dev/pts/2')])

    @unittest.skipUnless(hasattr(os, 'openpty'), 'PTY requires POSIX support')
    def test_live_update_writes_output_to_pty_without_shell_input(self):
        master, slave = os.openpty()
        try:
            with patch.object(terminal, 'terminal_ptys', return_value=[Path(os.ttyname(slave))]):
                self.assertEqual(terminal.refresh(PALETTE), [])
            self.assertEqual(os.read(master, 4096), terminal.sequences(PALETTE))
            os.set_blocking(slave, False)
            with self.assertRaises(BlockingIOError): os.read(slave, 4096)
        finally:
            os.close(master); os.close(slave)

    def test_unsafe_colors_are_rejected_before_any_terminal_write(self):
        with self.assertRaises(ConfigError):
            terminal.sequences(PALETTE | {'accent': '#fff\ncommand'})

    def test_toolkit_primary_roles_match_exact_selected_colors(self):
        for original, role in (('#202729', 'background'), ('#272d2d', 'background'),
                               ('#2e3734', 'surface'), ('#a9b99a', 'accent'), ('#e7e9e5', 'text')):
            self.assertEqual(themes.map_color(original, PALETTE), PALETTE[role])
