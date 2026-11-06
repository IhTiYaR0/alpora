"""Delayed native cursor results must not close a newly selected/reopened panel."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'),'Quickshell required')
class PointerExitTests(unittest.TestCase):
    def test_stale_cursor_query_does_not_dismiss_new_owner(self):
        with tempfile.TemporaryDirectory(prefix='poly-pointer-exit-') as temporary:
            d=Path(temporary)
            shutil.copy(ROOT/'shell/core/PointerExitGuard.qml',d/'PointerExitGuard.qml')
            (d/'qmldir').write_text('PointerExitGuard 1.0 PointerExitGuard.qml\n')
            (d/'hyprctl').write_text('#!/usr/bin/python3\nimport time\ntime.sleep(.15)\nprint(\'{"x":0,"y":0}\')\n')
            (d/'hyprctl').chmod(0o755)
            (d/'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
 id:test
 property int dismissed:0
 QtObject {id:bar;function buttonBounds(item) {return {x:100,y:0,width:30,height:40};}}
 Item {id:source;width:30;height:40}
 PointerExitGuard {
  id:guard;enabledForClose:true;pointerInside:false;barWindow:bar;sourceItem:source
  screenOffset:Qt.point(0,0);panelBounds:Qt.rect(100,50,300,300);ownerToken:"old"
  onOutside:test.dismissed+=1
 }
 Component.onCompleted:guard.check()
 Timer {interval:40;running:true;onTriggered:{guard.ownerToken="new";guard.pointerInside=true;}}
 Timer {interval:280;running:true;onTriggered: {
  if(test.dismissed!==0)throw new Error("Old cursor result dismissed the new panel");
  guard.pointerInside=false;guard.check();
 }}
 Timer {interval:540;running:true;onTriggered: {
  if(test.dismissed!==1)throw new Error("Current cursor query must still dismiss outside");
  guard.check();guard.enabledForClose=false;guard.enabledForClose=true;guard.pointerInside=true;
 }}
 Timer {interval:800;running:true;onTriggered: {
  if(test.dismissed!==1)throw new Error("Old cursor result dismissed a reopened panel");
  guard.pointerInside=false;guard.check();guard.ownerToken="third";
 }}
 Timer {interval:1250;running:true;onTriggered:{
  if(test.dismissed!==2)throw new Error("New owner must receive a fresh outside query after stale request finishes");
  console.info("POINTER_GENERATION_OK");Qt.quit();
 }}
 Timer {interval:2500;running:true;onTriggered:Qt.quit()}
}
''')
            env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='generic',PATH=str(d)+':/usr/bin:/bin',XDG_RUNTIME_DIR=str(d))
            result=subprocess.run(['quickshell','--path',str(d)],env=env,capture_output=True,text=True,timeout=5)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            self.assertIn('POINTER_GENERATION_OK',output)
