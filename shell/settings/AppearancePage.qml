pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import "../logic/AppearanceCatalog.js" as Catalog

ScrollView {
 id: root
 property string element: AppearanceState.element
 contentWidth: availableWidth; clip: true
 ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
 rightPadding: 6
 onElementChanged: { const view = contentItem as Flickable; if (view) view.contentY = 0; }
 Component.onCompleted: AppearanceState.begin()
 ColumnLayout {
  width: root.availableWidth; spacing: 12
  Repeater {
   model: Catalog.groups(root.element)
   AppearanceSection {
    id: group
    required property var modelData
    Layout.fillWidth: true
    title: modelData.title; symbol: modelData.icon
    description: modelData.title === I18n.tr("appearance.field.section_material") ? I18n.tr("appearance.desc_material") : modelData.title === I18n.tr("appearance.field.section_shadow") ? I18n.tr("appearance.desc_shadow") : modelData.title === I18n.tr("appearance.field.section_animations") ? I18n.tr("appearance.desc_anim") : root.element === "window" ? I18n.tr("appearance.desc_window") : root.element === "bar" && modelData.title === I18n.tr("appearance.field.section_placement") ? I18n.tr("appearance.desc_bar") : ""
    Repeater {
     model: group.modelData.fields
     AppearanceSlider {
      required property var modelData
      Layout.fillWidth: true
      settingKey: modelData.key; label: modelData.label; minimum: modelData.min; maximum: modelData.max; suffix: modelData.suffix
     }
    }
   }
  }
  AppearanceSection {
   Layout.fillWidth: true; visible: root.element === "widget"
   title: I18n.tr("appearance.widget_motion"); description: I18n.tr("appearance.widget_motion_desc"); symbol: "music"
   RowLayout {
    Layout.fillWidth: true
    Text { Layout.fillWidth: true; text: I18n.tr("appearance.decorative_animations"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap }
    SettingsToggle { checked: !!AppearanceState.draft.widgetAnimations; enabled: !AppearanceState.busy; Accessible.name: I18n.tr("appearance.decorative_animations"); onToggled: AppearanceState.edit("widgetAnimations", checked) }
   }
  }
  AppearanceSection {
   Layout.fillWidth: true; visible: root.element === "window" || root.element === "panel" || root.element === "bar" || root.element === "launcher"
   title: I18n.tr("appearance.blur_title"); description: I18n.tr("appearance.blur_desc"); symbol: "blur"
   RowLayout {
    Layout.fillWidth: true
    Text { Layout.fillWidth: true; text: I18n.tr("appearance.blur_background"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12 }
    SettingsToggle { checked: !!AppearanceState.draft.blurEnabled; enabled: !AppearanceState.busy; Accessible.name: I18n.tr("appearance.blur_background"); onToggled: AppearanceState.edit("blurEnabled", checked) }
   }
   AppearanceSlider { Layout.fillWidth: true; settingKey: "blurSize"; label: I18n.tr("appearance.blur_strength"); minimum: 1; maximum: 8; suffix: ""; enabled: !!AppearanceState.draft.blurEnabled }
   AppearanceSlider { Layout.fillWidth: true; settingKey: "blurPasses"; label: I18n.tr("appearance.blur_passes"); minimum: 1; maximum: 2; suffix: ""; enabled: !!AppearanceState.draft.blurEnabled }
  }
 }
}
