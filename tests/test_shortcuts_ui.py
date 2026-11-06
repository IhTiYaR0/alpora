"""Run real shortcut editor/state code offscreen, without changing the desktop."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('quickshell'),'Quickshell required')
class ShortcutEditorTests(unittest.TestCase):
    def test_editor_add_apply_remove_reload_and_unsaved_form_state(self):
        with tempfile.TemporaryDirectory(prefix='poly-shortcuts-ui-') as temporary:
            d=Path(temporary)
            file_map = {'SettingsShortcuts.qml': ROOT/'shell/settings/SettingsShortcuts.qml', 'ShortcutsState.qml': ROOT/'shell/core/ShortcutsState.qml'}
            for name, p in file_map.items():
                source = p.read_text()
                if name=='SettingsShortcuts.qml':source=source.replace('id: root','id: root\n    property alias testFooter:footer',1)
                (d/name).write_text(source)
            (d/'qmldir').write_text('singleton Session 1.0 Session.qml\nsingleton ShortcutsState 1.0 ShortcutsState.qml\nsingleton Glass 1.0 Glass.qml\nsingleton I18n 1.0 I18n.qml\nSettingsShortcuts 1.0 SettingsShortcuts.qml\nSettingsCard 1.0 SettingsCard.qml\nAppearanceButton 1.0 AppearanceButton.qml\n')
            (d/'Glass.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {function tint(c, a) { return c; }}\n')
            (d/'I18n.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {function tr(k) { return k }\nfunction trWith(k, p) { return k }\n}\n')
            (d/'SettingsCard.qml').write_text('import QtQuick.Layouts\nColumnLayout {property int padding:18}\n')
            (d/'AppearanceButton.qml').write_text('import QtQuick.Controls\nButton {property string symbol:"";property bool primary:false;property bool selected:false}\n')
            (d/'Session.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {readonly property color accent:"#aabbcc";readonly property color background:"#101010";readonly property color foreground:"white";readonly property color muted:"gray";readonly property color surface:"#303030";readonly property string fontFamily:"Sans";readonly property string controller:'+json.dumps(str(d/'controller'))+'}\n')
            (d/'controller').write_text('''#!/usr/bin/python3
import json,sys
from pathlib import Path
file=Path(__file__).with_name('values.json')
values=json.loads(file.read_text()) if file.exists() else []
if sys.argv[2]=='get':print(json.dumps(dict(values=values,actions=[dict(id='command',title='Запуск')],globals=[],external=[])))
else:
 request=json.loads(sys.argv[3]);assert request['expected']==values
 file.write_text(json.dumps(request['values']));print(json.dumps(dict(saved=True,values=request['values'])))
''')
            (d/'controller').chmod(0o755)
            (d/'shell.qml').write_text('''import QtQuick
import QtQuick.Window
import Quickshell
ShellRoot {
 id:test
 property int stage:0
 Window {visible:true;width:820;height:600;SettingsShortcuts {id:editor;anchors.fill:parent}}
 Timer {
  interval:40;repeat:true;running:true
  onTriggered: {
   if(ShortcutsState.error)throw new Error(ShortcutsState.error);
   if(test.stage===0 && ShortcutsState.loaded) {
    editor.open({id:"custom-test",source:"",key:"SUPER + F8",title:"Тест",action:"command",argument:"true",enabled:true,locked:false,repeat:false});
    if(!ShortcutsState.editingForm)throw new Error("Form is not protected from close");
    test.stage=10;
   }else if(test.stage===10) {
    if(editor.testFooter.y+editor.testFooter.height>editor.height+1)throw new Error("Form actions overflow settings area");
    editor.saveForm();
    if(!ShortcutsState.dirty || ShortcutsState.editingForm || ShortcutsState.draft.length!==1)throw new Error("Editor did not commit draft");
    ShortcutsState.apply();test.stage=1;
   }else if(test.stage===1 && !ShortcutsState.busy && !ShortcutsState.dirty) {
    if(ShortcutsState.values.length!==1)throw new Error("Apply did not persist");
    ShortcutsState.remove("custom-test");ShortcutsState.apply();test.stage=2;
   }else if(test.stage===2 && !ShortcutsState.busy && !ShortcutsState.dirty) {
    if(ShortcutsState.values.length!==0)throw new Error("Remove failed");
    ShortcutsState.refresh();test.stage=3;
   }else if(test.stage===3 && !ShortcutsState.busy) {
    if(ShortcutsState.draft.length!==0)throw new Error("Reload brought back deleted record");
    console.info("SHORTCUT_EDITOR_OK");Qt.quit();
   }
  }
 }
 Timer {interval:5000;running:true;onTriggered:Qt.quit()}
}
''')
            env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='generic',QT_QUICK_CONTROLS_STYLE='Basic',XDG_RUNTIME_DIR=str(d))
            result=subprocess.run(['quickshell','--path',str(d)],env=env,capture_output=True,text=True,timeout=8)
            output=result.stdout+result.stderr
            self.assertEqual(result.returncode,0,output)
            self.assertIn('SHORTCUT_EDITOR_OK',output)
            self.assertNotIn('ReferenceError',output)
            self.assertNotIn('TypeError',output)
            self.assertNotIn('Binding loop',output)
