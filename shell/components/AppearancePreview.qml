pragma ComponentBehavior: Bound
import QtQuick
import ".."
import Quickshell

Rectangle {
 id: preview
 property url wallpaper: "file://" + Quickshell.env("POLY_SHELL_ASSETS") + "/wallpapers/alpine-dawn.png"
 property string element: "panel"
 property bool dark: true
 readonly property var draft: AppearanceState.draft
 readonly property string prefix: element === "window" ? "panel" : element
 readonly property int selectedRadius: draft[element === "window" ? "windowRadius" : prefix + "Radius"] || 0
 readonly property int selectedOpacity: draft[element === "window" ? "activeOpacity" : prefix + "Opacity"] || 0
 readonly property int selectedPadding: draft[prefix + "Padding"] === undefined ? 12 : draft[prefix + "Padding"]
 radius: 14; color: Session.background; border.width: 1; border.color: Glass.tint(Session.accent, 0.3); clip: true
 SettingsImage { anchors.fill: parent; source: preview.wallpaper; radius: 14; sourceSize: Qt.size(640, 572) }
 Rectangle { anchors.fill: parent; radius: 14; color: preview.dark ? Glass.tint(Session.background, 0.22) : Glass.tint(Session.foreground, 0.10) }
 Rectangle {
  id: mockBar
  x: 5 + preview.draft.barLeft * 0.35; y: 5 + preview.draft.barTop * 0.35
  width: parent.width - x - 5 - preview.draft.barRight * 0.35
  height: Math.max(24, preview.draft.barHeight * 0.45)
  radius: Math.min(height / 2, preview.draft.barRadius * 0.65)
  color: Glass.tint(Session.surface, preview.draft.barOpacity / 100)
  border.width: preview.draft.barBorder; border.color: Session.accent
  Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "◈   1  2  3"; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 9 }
  Text { anchors.centerIn: parent; text: "12:30"; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 9 }
  Icon { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: 13; height: 13; name: "wifi" }
 }
 Row {
  id: windows
  visible: preview.element === "window"
  x: 5 + preview.draft.windowMargin * 0.35
  y: mockBar.y + mockBar.height + (preview.draft.barBottom + preview.draft.windowMargin) * 0.35
  width: preview.width - x * 2
  height: Math.max(18, preview.height - y - 12 - preview.draft.windowMargin * 0.35)
  spacing: preview.draft.windowGap * 2 * 0.35
  Repeater {
   model: 2
   Rectangle {
    id: mockWindow
    required property int index
    width: Math.max(8, (windows.width - windows.spacing) / 2); height: windows.height
    radius: preview.draft.windowRadius * 0.45
    color: Session.surface; border.width: 1; border.color: Session.accent
    opacity: (index === 0 ? preview.draft.activeOpacity : preview.draft.inactiveOpacity) / 100
    clip: true
    Column {
     anchors.fill: parent; anchors.margins: 8; spacing: 8
     Text { text: I18n.tr("appearance.preview_window_num") + " " + (mockWindow.index + 1); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 10 }
     Rectangle { width: Math.max(0, parent.width); height: 4; radius: 2; color: Glass.tint(Session.accent, 0.65) }
     Rectangle { width: Math.max(0, parent.width * 0.65); height: 4; radius: 2; color: Glass.tint(Session.accent, 0.35) }
    }
   }
  }
 }
 Item {
  id: mock
  x: preview.element === "window" ? 22 : 58
  y: preview.element === "bar" ? 80 : 57
  width: preview.width - x - 18; height: preview.height - y - 22
  visible: preview.element !== "bar" && preview.element !== "window"
  opacity: preview.element === "window" ? preview.selectedOpacity / 100 : 1
  SoftShadow { anchors.fill: parent; cornerRadius: surface.radius; strength: (preview.draft[preview.prefix + "Shadow"] || 0) / 20 }
  Rectangle {
   id: surface
   anchors.fill: parent; radius: preview.selectedRadius * 0.65
   color: Glass.tint(Session.surface, preview.element === "window" ? 1 : preview.selectedOpacity / 100)
   border.width: preview.element === "window" ? 1 : preview.draft[preview.prefix + "Border"]
   border.color: Session.accent
   Column {
    anchors.fill: parent; anchors.margins: preview.selectedPadding * 0.7 + 3; spacing: 10
    Row {
     spacing: 7
     Icon { width: 15; height: 15; name: preview.element === "launcher" ? "search" : preview.element === "notification" ? "bell" : preview.element === "widget" ? "music" : "settings" }
     Text { text: preview.element === "window" ? I18n.tr("appearance.preview_app_window") : preview.element === "launcher" ? I18n.tr("appearance.preview_search_apps") : preview.element === "notification" ? I18n.tr("appearance.preview_notification") : preview.element === "widget" ? I18n.tr("music.title") : I18n.tr("quick.title"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 10 }
    }
    MountainRidge { width: parent.width; height: 34; visible: preview.element !== "notification" }
    Row {
     spacing: 7; visible: preview.element === "panel"
     Repeater { model: ["Wi-Fi", "Bluetooth"]; Rectangle { required property string modelData; width: (surface.width - 46) / 2; height: 35; radius: 8; color: Glass.tint(Session.accent, 0.15); border.width: 1; border.color: Glass.tint(Session.accent, 0.3); Text { anchors.centerIn: parent; text: parent.modelData; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 9 } } }
    }
    Text { visible: preview.element === "notification"; text: I18n.tr("common.all_saved"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11 }
    Repeater { model: preview.element === "launcher" ? 3 : 2; Rectangle { required property int index; width: parent.width * (index === 0 ? 0.92 : 0.68); height: preview.element === "launcher" ? 20 : 5; radius: 3; color: Glass.tint(Session.accent, index === 0 ? 0.8 : 0.35) } }
   }
  }
 }
 Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 8; anchors.horizontalCenter: parent.horizontalCenter; visible: preview.element === "bar"; text: I18n.trWith("appearance.bar_dimensions", {height: preview.draft.barHeight, bottom: preview.draft.barBottom}); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11 }
}
