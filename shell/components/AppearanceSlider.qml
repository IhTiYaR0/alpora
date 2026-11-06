pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
 id: root
 required property string settingKey
 required property string label
 property string symbol: "rounded"
 property int minimum: 0
 property int maximum: 100
 property string suffix: " px"
 readonly property int currentValue: AppearanceState.draft[settingKey] === undefined ? minimum : AppearanceState.draft[settingKey]
 spacing: 2
 RowLayout {
  Layout.fillWidth: true; spacing: 8
  Text { Layout.fillWidth: true; text: root.label; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap }
  TextField {
   id: number
   Layout.preferredWidth: 48; implicitHeight: 30
   text: String(root.currentValue)
   validator: IntValidator { bottom: root.minimum; top: root.maximum }
   inputMethodHints: Qt.ImhDigitsOnly
   horizontalAlignment: TextInput.AlignHCenter
   color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12; selectByMouse: true
   enabled: !AppearanceState.busy
   Accessible.name: root.label
   onEditingFinished: { if (acceptableInput) AppearanceState.edit(root.settingKey, Number(text)); text = Qt.binding(() => String(root.currentValue)); }
   background: Rectangle { radius: 8; color: Glass.tint(Session.background, 0.5); border.width: 1; border.color: number.activeFocus ? Session.accent : Glass.tint(Session.accent, 0.25) }
  }
  Text { Layout.preferredWidth: 20; text: root.suffix.trim(); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11 }
 }
 ControlSlider {
  Layout.fillWidth: true
  // Let the settings ScrollView handle mouse-wheel and touchpad scrolling.
  wheelEnabled: false
  from: root.minimum; to: root.maximum; stepSize: 1
  value: root.currentValue; enabled: !AppearanceState.busy
  Accessible.name: root.label
  onMoved: AppearanceState.edit(root.settingKey, Math.round(value))
 }
}
