pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Layouts
import "../theme" as PolyTheme
import "../logic/AppearanceCatalog.js" as Catalog

ColumnLayout {
 id: root
 property url wallpaper: ""
 readonly property var selected: Catalog.elements.find(e => e.id === AppearanceState.element) || Catalog.elements[2]
 spacing: 12
 RowLayout {
  Layout.fillWidth: true; spacing: 5
  Repeater {
   model: Catalog.elements
   AppearanceButton {
    required property var modelData
    Layout.fillWidth: true; Layout.minimumWidth: 0
    text: modelData.title; symbol: modelData.icon
    selected: AppearanceState.element === modelData.id
    leftPadding: 8; rightPadding: 8
    onClicked: AppearanceState.element = modelData.id
   }
  }
 }
 RowLayout {
  Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0; spacing: 16
  AppearancePage { Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0; Layout.minimumWidth: 330 }
  ColumnLayout {
   Layout.preferredWidth: 320; Layout.fillHeight: true; Layout.minimumHeight: 0; spacing: 10
   Text { text: I18n.tr("common.preview_caps"); color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 11; font.letterSpacing: 1 }
   AppearancePreview { id: preview; wallpaper: root.wallpaper; element: AppearanceState.element; Layout.fillWidth: true; Layout.preferredHeight: 210 }
   RowLayout {
    Layout.fillWidth: true; spacing: 8
    AppearanceButton { Layout.fillWidth: true; text: I18n.tr("common.light"); symbol: "sun"; selected: !preview.dark; onClicked: preview.dark = false }
    AppearanceButton { Layout.fillWidth: true; text: I18n.tr("common.dark"); symbol: "moon"; selected: preview.dark; onClicked: preview.dark = true }
   }
   AppearanceSection {
    Layout.fillWidth: true; title: root.selected.title; symbol: root.selected.icon; description: root.selected.description
    Text { Layout.fillWidth: true; text: I18n.tr("appearance.theme_persist_hint"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
   }
   Text { Layout.fillWidth: true; text: I18n.tr("appearance.layout_hint"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; wrapMode: Text.Wrap }
   Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
   AppearanceButton { Layout.fillWidth: true; text: I18n.tr("appearance.reset_element"); symbol: "refresh"; enabled: !AppearanceState.busy; onClicked: AppearanceState.resetElement() }
  }
 }
 Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Glass.tint(Session.accent, 0.2) }
 RowLayout {
  Layout.fillWidth: true; Layout.preferredHeight: 44; spacing: 10
  Rectangle { Layout.preferredWidth: 7; Layout.preferredHeight: 7; radius: 4; color: AppearanceState.dirty ? PolyTheme.Theme.secondary : Session.accent }
  Text { Layout.fillWidth: true; text: AppearanceState.error || AppearanceState.message || (AppearanceState.dirty ? I18n.tr("common.unsaved_changes") : I18n.tr("common.all_saved")); color: AppearanceState.error ? PolyTheme.Theme.secondary : Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
  AppearanceButton { text: I18n.tr("common.cancel"); symbol: "close"; enabled: !AppearanceState.busy && (AppearanceState.dirty || !!AppearanceState.error); onClicked: AppearanceState.cancel() }
  AppearanceButton { text: AppearanceState.busy ? I18n.tr("common.saving") : I18n.tr("common.apply"); symbol: "check"; primary: true; enabled: AppearanceState.dirty && !AppearanceState.busy; onClicked: AppearanceState.apply() }
 }
}
