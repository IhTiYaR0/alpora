"""Arch setup must preserve personal configs and recover from partial writes."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from poly_shell import bootstrap, themes
from poly_shell.state import ConfigError, Paths, update_session, read_object

ROOT=Path(__file__).resolve().parents[1]

class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='alpora setup ');self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.paths=Paths(self.root/'config/poly-shell',self.root/'state',self.root/'runtime')
        self.hypr=self.root/'config/hypr';self.hypr.mkdir(parents=True)

    def test_personal_main_refused_without_change(self):
        main=self.hypr/'hyprland.lua';main.write_text('-- personal\n')
        with self.assertRaises(ConfigError):bootstrap.configure(self.paths)
        self.assertEqual(main.read_text(),'-- personal\n')
        self.assertFalse((self.hypr/'alpora-session.lua').exists())

    def test_first_setup_repeat_backup_and_generated_lock(self):
        result=bootstrap.configure(self.paths)
        main=self.hypr/'hyprland.lua';self.assertTrue(main.read_text().startswith(bootstrap.MARKER))
        lock=(self.hypr/'hyprlock.conf').read_text()
        self.assertIn('lockscreen/layout.conf',lock);self.assertIn('hyprlock-theme.conf',lock)
        self.assertTrue(os.access(self.hypr/'screenshot.sh',os.X_OK))
        self.assertTrue(Path(result['backup']).is_dir())
        original=main.read_text();bootstrap.configure(self.paths)
        self.assertEqual(main.read_text(),original)

    def test_explicit_replace_backs_up_main_and_legacy_config(self):
        main=self.hypr/'hyprland.lua';main.write_text('-- personal Lua')
        legacy=self.hypr/'hyprland.conf';legacy.write_text('personal legacy')
        extra=self.hypr/'notes';extra.write_text('keep')
        result=bootstrap.configure(self.paths,replace=True);backup=Path(result['backup'])/'hypr'
        self.assertEqual((backup/'hyprland.lua').read_text(),'-- personal Lua')
        self.assertEqual((backup/'hyprland.conf').read_text(),'personal legacy')
        self.assertFalse(legacy.exists());self.assertEqual(extra.read_text(),'keep')

    @unittest.skipIf(os.name == 'nt', 'Symlink creation requires Linux / POSIX environment')
    def test_failed_hook_restores_external_symlink_and_all_original_files(self):
        external=self.root/'external.lua';external.write_text('-- external config')
        main=self.hypr/'hyprland.lua';main.symlink_to(external)
        with patch.object(bootstrap,'install_hook',side_effect=OSError('disk full')):
            with self.assertRaises(OSError):bootstrap.configure(self.paths,replace=True)
        self.assertTrue(main.is_symlink());self.assertEqual(main.resolve(),external)
        self.assertEqual(external.read_text(),'-- external config')
        self.assertFalse((self.hypr/'alpora-session.lua').exists())

    def test_modified_session_file_is_not_silently_overwritten(self):
        bootstrap.configure(self.paths)
        target=self.hypr/'alpora-session.lua';target.write_text('-- my settings')
        with self.assertRaises(ConfigError):bootstrap.configure(self.paths)
        self.assertEqual(target.read_text(),'-- my settings')

    def test_offline_theme_preparation_does_not_touch_running_session(self):
        update_session(self.paths,'vibe')
        with patch.object(themes,'runtime_border') as border,patch.object(themes,'notify_toolkit') as notify,patch('poly_shell.desktop._wallpaper') as wallpaper,patch.object(themes.subprocess,'run') as run:
            result=themes.apply_theme(self.paths,'moon-lake',activate=False)
        border.assert_not_called();notify.assert_not_called();wallpaper.assert_not_called();run.assert_not_called()
        self.assertTrue(result['prepared'])
        self.assertEqual(read_object(self.paths.session)['mode'],'vibe')
        self.assertIn('moon-lake.png',read_object(self.paths.config/'wallpaper.json')['image'])
        self.assertTrue((self.paths.state/'hyprlock-theme.conf').exists())

    @unittest.skipIf(os.name == 'nt', 'Bash installer requires Linux / POSIX environment')
    def test_install_dry_run_changes_nothing(self):
        env=dict(os.environ,HOME=str(self.root),XDG_CONFIG_HOME=str(self.root/'config'),XDG_STATE_HOME=str(self.root/'state'))
        for flags,marker in ((['--dry-run'],'no changes'),
                             (['--preview','--theme=northern-lights'],'PREVIEW / No installation')):
            with self.subTest(flags=flags):
                result=subprocess.run([str(ROOT/'install/install.sh'),*flags],env=env,capture_output=True,text=True,timeout=5)
                self.assertEqual(result.returncode,0,result.stderr)
                self.assertIn(marker,result.stdout)
                self.assertNotIn('\x1b[',result.stdout)
                self.assertFalse((self.root/'state').exists())
                self.assertFalse(list(self.hypr.iterdir()))

    @unittest.skipIf(os.name == 'nt', 'Symlink creation requires Linux / POSIX environment')
    def test_setup_orchestration_runs_offline_and_preserves_running_signature(self):
        env={'HOME':str(self.root),'XDG_CONFIG_HOME':str(self.root/'config'),
             'XDG_STATE_HOME':str(self.root/'local-state'),'XDG_DATA_HOME':str(self.root/'data'),
             'XDG_RUNTIME_DIR':str(self.root/'runtime'),'HYPRLAND_INSTANCE_SIGNATURE':'existing-session'}
        with patch.dict(os.environ,env),patch('poly_shell.cli.runtime_check'),patch.object(bootstrap.shutil,'which',return_value='/usr/bin/tool'),patch.object(bootstrap.desktop_assets,'install') as assets_install,patch.object(bootstrap.desktop_assets,'apply') as assets_apply,patch.object(bootstrap,'enable_services'),patch.object(themes,'runtime_border') as border,patch.object(themes,'notify_toolkit') as notify,patch('poly_shell.desktop._wallpaper') as wallpaper:
            self.assertEqual(bootstrap.main([]),0)
            current=Paths.current()
            self.assertTrue((self.root/'.local/bin/poly-shell').is_symlink())
            self.assertTrue((self.root/'.local/bin/alpora-fetch').is_symlink())
            self.assertTrue((self.hypr/'alpora-session.lua').is_file())
            self.assertTrue((current.state/'mako-theme.conf').is_file())
            self.assertTrue((current.state/'hyprlock-theme.conf').is_file())
            self.assertIn('alpine-dawn.png',read_object(current.config/'wallpaper.json')['image'])
            self.assertEqual(os.environ['HYPRLAND_INSTANCE_SIGNATURE'],'existing-session')
            self.assertEqual(bootstrap.main(['--theme','northern-lights']),0)
            self.assertEqual(read_object(current.session)['appearance']['id'],'northern-lights')
            (self.root/'.local/bin/alpora-fetch').unlink()
            with self.assertRaisesRegex(ConfigError,'alpora-fetch'):
                bootstrap.verify_prepared_desktop(current)
            self.assertEqual(assets_install.call_count,2);self.assertEqual(assets_apply.call_count,2)
            border.assert_not_called();notify.assert_not_called();wallpaper.assert_not_called()

    @unittest.skipIf(os.name == 'nt', 'Symlink creation requires Linux / POSIX environment')
    def test_ui_only_install_does_not_touch_hypr_config(self):
        env={'HOME':str(self.root),'XDG_CONFIG_HOME':str(self.root/'config'),
             'XDG_STATE_HOME':str(self.root/'local-state'),'XDG_DATA_HOME':str(self.root/'data'),
             'XDG_RUNTIME_DIR':str(self.root/'runtime')}
        personal_hypr = self.hypr / 'hyprland.conf'
        personal_hypr.write_text('# My personal hyprland config\n')
        with patch.dict(os.environ,env),patch('poly_shell.cli.runtime_check'),patch.object(bootstrap.shutil,'which',return_value='/usr/bin/quickshell'),patch.object(bootstrap.desktop_assets,'install'),patch.object(bootstrap.desktop_assets,'apply'),patch.object(themes,'runtime_border'),patch.object(themes,'notify_toolkit'),patch('poly_shell.desktop._wallpaper'):
            self.assertEqual(bootstrap.main(['--ui-only']),0)
            self.assertEqual(personal_hypr.read_text(),'# My personal hyprland config\n')
            self.assertFalse((self.hypr/'alpora-session.lua').exists())
            self.assertFalse((self.hypr/'hyprland.lua').exists())
            self.assertTrue((self.root/'.local/bin/poly-shell').is_symlink())
            self.assertTrue((self.root/'.local/bin/alpora-fetch').is_symlink())

    def test_reference_preset_matches_release_geometry_and_preserves_existing_preferences(self):
        from poly_shell.state import atomic_json
        existing=self.paths.config/'widgets.json'
        atomic_json(existing,{'my':'existing preferences'})
        created=bootstrap.seed_reference_preferences(self.paths)
        self.assertEqual(read_object(existing),{'my':'existing preferences'})
        visual=read_object(self.paths.config/'visual.json')['values']
        self.assertEqual(visual['windowRadius'],20)
        self.assertFalse(visual['blurEnabled'])
        self.assertEqual(visual['barHeight'],40)
        self.assertTrue(read_object(self.paths.config/'companion.json')['flights'])
        self.assertFalse(read_object(self.paths.config/'landscape.json')['enabled'])
        self.assertEqual(len(created),4)
        self.assertEqual(bootstrap.seed_reference_preferences(self.paths),[])
        self.assertFalse((self.paths.config/'organizer.json').exists())
        self.assertFalse((self.paths.config/'clipboard').exists())

    @unittest.skipIf(os.name == 'nt', 'PTY wizard requires Linux / POSIX environment')
    def test_real_wizard_selection_is_preview_only(self):
        import pty
        import select
        import time
        master,slave=pty.openpty()
        env=dict(os.environ,HOME=str(self.root),XDG_CONFIG_HOME=str(self.root/'config'),XDG_STATE_HOME=str(self.root/'state'),TERM='xterm-256color',NO_COLOR='1')
        process=subprocess.Popen([str(ROOT/'install/install.sh'),'--dry-run','--wizard'],stdin=slave,stdout=slave,stderr=slave,env=env)
        os.close(slave)
        output=b''
        try:
            end=time.monotonic()+5;selected=False
            while time.monotonic()<end:
                if select.select([master],[],[],.1)[0]:
                    try:chunk=os.read(master,65536)
                    except OSError:break
                    if not chunk:break
                    output+=chunk
                    if b'Landscape [1' in output and not selected:
                        os.write(master,b'5\n');selected=True
                if process.poll() is not None:
                    try:output+=os.read(master,65536)
                    except OSError:pass
                    break
            process.wait(timeout=2)
            self.assertEqual(process.returncode,0,output.decode())
            self.assertIn(b'Landscape      northern-lights',output)
            self.assertNotIn(b'\x1b[',output)
            self.assertFalse((self.root/'state').exists())
            self.assertFalse(list(self.hypr.iterdir()))
        finally:
            os.close(master)
            if process.poll() is None:process.kill();process.wait()

    def test_prepared_desktop_verification_rejects_missing_components(self):
        update_session(self.paths)
        with self.assertRaises(ConfigError):bootstrap.verify_prepared_desktop(self.paths)

    def test_active_but_disabled_network_service_is_enabled_without_restart(self):
        import subprocess
        def run(command,**kwargs):
            code=1 if command==['systemctl','is-enabled','--quiet','NetworkManager.service'] else 0
            return subprocess.CompletedProcess(command,code)
        with patch.object(bootstrap.subprocess,'run',side_effect=run) as calls:
            bootstrap.enable_services()
        commands=[call.args[0] for call in calls.call_args_list]
        self.assertIn(['sudo','systemctl','enable','NetworkManager.service'],commands)
        self.assertNotIn(['sudo','systemctl','enable','--now','NetworkManager.service'],commands)
        self.assertFalse(any('restart' in command for command in commands))
