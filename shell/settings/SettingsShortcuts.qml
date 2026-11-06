pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 12
    property var editing: null
    property string formError: ""
    property string viewMode: "guide"
    onEditingChanged: ShortcutsState.editingForm=!!editing
    Component.onDestruction: ShortcutsState.editingForm=false
    readonly property string action: ShortcutsState.actions[actionSelect.currentIndex]?.id || "command"
    readonly property var shown: ShortcutsState.draft.filter(r=>(showDisabled.checked || r.enabled)
        && (!search.text.trim() || [r.title,r.key,r.argument].join(" ").toLowerCase().includes(search.text.trim().toLowerCase())))
    Component.onCompleted: ShortcutsState.refresh()
    function open(item: var): void {
        viewMode="custom";
        editing=ShortcutsState.copy(item);formError="";
        titleField.text=item.title;keyField.text=item.key;argumentField.text=item.argument;
        actionSelect.currentIndex=Math.max(0,ShortcutsState.actions.findIndex(a=>a.id===item.action));
        globalSelect.currentIndex=Math.max(0,ShortcutsState.globals.findIndex(a=>a.id===item.argument));
        activeCheck.checked=item.enabled;repeatCheck.checked=item.repeat;lockedCheck.checked=item.locked;
    }
    function saveForm(): void {
        const argument=action==="global"?(ShortcutsState.globals[globalSelect.currentIndex]?.id || ""):argumentField.text;
        if(!titleField.text.trim() || !keyField.text.trim() || (["command","workspace","move-workspace"].includes(action) && !argument.trim())) {
            formError=I18n.tr("shortcuts.fill_all_fields");return;
        }
        const duplicate=ShortcutsState.draft.some(r=>r.id!==editing.id && r.enabled && activeCheck.checked
            && r.key.replace(/\s/g,"").toUpperCase()===keyField.text.replace(/\s/g,"").toUpperCase());
        if(duplicate){formError=I18n.tr("shortcuts.already_occupied");return;}
        ShortcutsState.edit(Object.assign({},editing,{title:titleField.text.trim(),key:keyField.text.trim(),action:action,
            argument:argument,enabled:activeCheck.checked,repeat:repeatCheck.checked,locked:lockedCheck.checked}));
        editing=null;
    }
    Text {Layout.fillWidth:true;text:I18n.tr("shortcuts.title");color:Session.foreground;font.family:Session.fontFamily;font.pixelSize:18;font.weight:Font.Medium}
    Text {Layout.fillWidth:true;text:I18n.tr("shortcuts.desc");color:Session.muted;font.family:Session.fontFamily;font.pixelSize:12;wrapMode:Text.Wrap}
    RowLayout {
        Layout.fillWidth:true;spacing:8
        AppearanceButton {
            text: I18n.tr("shortcuts.guide_tab"); symbol: "monitor"
            selected: root.viewMode === "guide" && !root.editing
            onClicked: { root.viewMode = "guide"; root.editing = null; }
        }
        AppearanceButton {
            text: I18n.tr("shortcuts.custom_tab"); symbol: "settings"
            selected: root.viewMode === "custom" || !!root.editing
            onClicked: root.viewMode = "custom"
        }
        Item { Layout.fillWidth: true }
        AppearanceButton {
            visible: root.viewMode === "custom" || !!root.editing
            text: I18n.tr("common.add"); symbol: "plus"
            enabled: ShortcutsState.loaded && !ShortcutsState.busy && !root.editing
            onClicked: root.open({id:"custom-"+Date.now()+"-"+Math.floor(Math.random()*100000),source:"",key:"",title:"",action:"command",argument:"",enabled:true,locked:false,repeat:false})
        }
        AppearanceButton {
            visible: root.viewMode === "custom" || !!root.editing
            text: I18n.tr("common.refresh"); symbol: "refresh"
            enabled: !ShortcutsState.busy && !ShortcutsState.dirty && !root.editing
            onClicked: ShortcutsState.refresh()
        }
    }

    // Guide Tab: Visual Cheat Sheet
    ScrollView {
        id: guideScroll
        visible: root.viewMode === "guide" && !root.editing
        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 180
        clip: true; contentWidth: availableWidth
        ColumnLayout {
            width: guideScroll.availableWidth; spacing: 14
            component ShortcutItem: Rectangle {
                id: sItem
                required property string name
                required property var keys
                Layout.fillWidth: true; height: 44; radius: 9
                color: Glass.tint(Session.surface, 0.40)
                border.width: 1; border.color: Glass.tint(Session.accent, 0.12)
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: sItem.name; color: Session.foreground
                        font.family: Session.fontFamily; font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: sItem.keys
                            Rectangle {
                                required property string modelData
                                radius: 5; height: 24
                                width: Math.max(26, kLabel.implicitWidth + 12)
                                color: Glass.tint(Session.surface, 0.85)
                                border.width: 1; border.color: Glass.tint(Session.accent, 0.35)
                                Text {
                                    id: kLabel; anchors.centerIn: parent
                                    text: modelData; color: Session.accent
                                    font.family: Session.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }

            // System & Shell Group
            Text {
                text: I18n.tr("shortcuts.group_system")
                color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            ShortcutItem { name: I18n.tr("shortcut.launcher"); keys: ["Super", "Space"] }
            ShortcutItem { name: I18n.tr("shortcut.overview"); keys: ["Super", "Tab"] }
            ShortcutItem { name: I18n.tr("shortcut.quick_settings"); keys: ["Super", "I"] }
            ShortcutItem { name: I18n.tr("shortcut.toggle_mode"); keys: ["Super", "W"] }
            ShortcutItem { name: I18n.tr("shortcut.clipboard"); keys: ["Super", "V"] }
            ShortcutItem { name: I18n.tr("shortcut.notifications"); keys: ["Super", "N"] }
            ShortcutItem { name: I18n.tr("bar.lock_screen"); keys: ["Super", "L"] }
            ShortcutItem { name: I18n.tr("settings.power"); keys: ["Super", "Shift", "E"] }

            // Windows & Applications Group
            Item { Layout.preferredHeight: 6 }
            Text {
                text: I18n.tr("shortcuts.group_windows")
                color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            ShortcutItem { name: I18n.tr("bar.open_terminal"); keys: ["Super", "Return"] }
            ShortcutItem { name: I18n.tr("day.files"); keys: ["Super", "E"] }
            ShortcutItem { name: "Web Browser (Firefox)"; keys: ["Super", "B"] }
            ShortcutItem { name: "Close Window"; keys: ["Super", "Q"] }
            ShortcutItem { name: "Fullscreen Toggle"; keys: ["Super", "F"] }
            ShortcutItem { name: "Toggle Floating"; keys: ["Super", "Shift", "V"] }
            ShortcutItem { name: "Switch Active Window"; keys: ["Alt", "Tab"] }
            ShortcutItem { name: I18n.tr("quick.screenshot"); keys: ["Print"] }

            // Workspaces & Navigation Group
            Item { Layout.preferredHeight: 6 }
            Text {
                text: I18n.tr("shortcuts.group_workspaces")
                color: Session.accent; font.family: Session.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold
            }
            ShortcutItem { name: I18n.tr("overview.workspace") + " 1 … 9"; keys: ["Super", "1 - 9"] }
            ShortcutItem { name: "Move Window to Workspace 1 … 9"; keys: ["Super", "Shift", "1 - 9"] }
            ShortcutItem { name: "Focus Window"; keys: ["Super", "← → ↑ ↓"] }
            ShortcutItem { name: "Swap / Move Window"; keys: ["Super", "Shift", "← → ↑ ↓"] }
            ShortcutItem { name: "Resize Window (Keyboard)"; keys: ["Super", "Ctrl", "← → ↑ ↓"] }

            // Customizer Callout
            Item { Layout.preferredHeight: 8 }
            SettingsCard {
                Layout.fillWidth: true
                RowLayout {
                    Layout.fillWidth: true; spacing: 14
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        Text { text: I18n.tr("shortcuts.custom_tab"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                        Text { text: I18n.tr("shortcuts.desc"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    }
                    AppearanceButton {
                        text: I18n.tr("shortcuts.custom_tab"); symbol: "settings"; primary: true
                        onClicked: root.viewMode = "custom"
                    }
                }
            }
        }
    }

    // Customizer Tab: Search, Add, Edit & List
    RowLayout {
        visible: root.viewMode === "custom" && !root.editing
        Layout.fillWidth: true; spacing: 8
        TextField {
            id: search
            palette.base: Session.surface; palette.button: Session.surface; palette.text: Session.foreground; palette.buttonText: Session.foreground; palette.highlight: Session.accent; palette.highlightedText: Session.background
            Layout.fillWidth: true; placeholderText: I18n.tr("shortcuts.search_placeholder"); color: Session.foreground; Accessible.name: I18n.tr("shortcuts.search_accessible")
        }
    }
    SettingsCard {
        Layout.fillWidth: true; visible: !!root.editing
        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: 12; rowSpacing: 8
            TextField { id: titleField; palette.base: Session.surface; palette.button: Session.surface; palette.text: Session.foreground; palette.buttonText: Session.foreground; palette.highlight: Session.accent; palette.highlightedText: Session.background; Layout.fillWidth: true; placeholderText: I18n.tr("shortcuts.action_title_placeholder"); maximumLength: 160; color: Session.foreground; Accessible.name: I18n.tr("shortcuts.title_accessible") }
            TextField { id: keyField; palette.base: Session.surface; palette.button: Session.surface; palette.text: Session.foreground; palette.buttonText: Session.foreground; palette.highlight: Session.accent; palette.highlightedText: Session.background; Layout.fillWidth: true; placeholderText: "SUPER + SHIFT + E"; maximumLength: 100; color: Session.foreground; Accessible.name: I18n.tr("shortcuts.key_accessible") }
            ComboBox { id: actionSelect; palette.base: Session.surface; palette.button: Session.surface; palette.text: Session.foreground; palette.buttonText: Session.foreground; palette.highlight: Session.accent; palette.highlightedText: Session.background; Layout.fillWidth: true; model: ShortcutsState.actions; textRole: "title"; Accessible.name: I18n.tr("shortcuts.action_accessible") }
            TextField { id: argumentField; palette.base: Session.surface; palette.button: Session.surface; palette.text: Session.foreground; palette.buttonText: Session.foreground; palette.highlight: Session.accent; palette.highlightedText: Session.background; Layout.fillWidth: true; visible: root.action !== "global"; enabled: ["command", "workspace", "move-workspace"].includes(root.action); placeholderText: root.action === "command" ? I18n.tr("shortcuts.cmd_placeholder") : I18n.tr("shortcuts.workspace_num_placeholder"); maximumLength: 4096; color: Session.foreground; Accessible.name: I18n.tr("shortcuts.arg_accessible") }
            ComboBox { id: globalSelect; palette.base: Session.surface; palette.button: Session.surface; palette.text: Session.foreground; palette.buttonText: Session.foreground; palette.highlight: Session.accent; palette.highlightedText: Session.background; Layout.fillWidth: true; visible: root.action === "global"; model: ShortcutsState.globals; textRole: "title"; Accessible.name: I18n.tr("shortcuts.global_accessible") }
        }
        Text { Layout.fillWidth: true; text: I18n.tr("shortcuts.key_hint"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
        RowLayout {
            Layout.fillWidth: true
            CheckBox { id: activeCheck; text: I18n.tr("common.enabled"); palette.windowText: Session.foreground }
            CheckBox { id: repeatCheck; text: I18n.tr("shortcuts.repeat_hold"); palette.windowText: Session.foreground }
            CheckBox { id: lockedCheck; text: I18n.tr("shortcuts.on_lockscreen"); palette.windowText: Session.foreground }
        }
        Text { Layout.fillWidth: true; visible: !!root.formError; text: root.formError; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            AppearanceButton { text: I18n.tr("shortcuts.cancel_editing"); symbol: "close"; onClicked: root.editing = null }
            AppearanceButton { text: I18n.tr("shortcuts.done"); symbol: "check"; primary: true; enabled: !ShortcutsState.busy; onClicked: root.saveForm() }
        }
    }
    CheckBox { id: showDisabled; visible: root.viewMode === "custom" && !root.editing; text: I18n.tr("shortcuts.show_disabled"); palette.windowText: Session.foreground }
    ListView {
        id: list
        visible: root.viewMode === "custom" && !root.editing
        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 100
        clip: true; spacing: 6; model: root.shown
        ScrollBar.vertical: ScrollBar {}
        delegate: Rectangle {
            id: shortcutRow
            required property var modelData
            width: list.width; height: 70; radius: 10; color: Session.surface
            opacity: modelData.enabled ? 1 : 0.6
            RowLayout {
                anchors.fill: parent; anchors.margins: 10; spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { Layout.fillWidth: true; text: shortcutRow.modelData.title; elide: Text.ElideRight; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13 }
                    Text { Layout.fillWidth: true; text: shortcutRow.modelData.key + " · " + (shortcutRow.modelData.action === "command" ? shortcutRow.modelData.argument : (ShortcutsState.actions.find(a => a.id === shortcutRow.modelData.action)?.title || "")); elide: Text.ElideRight; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11 }
                }
                AppearanceButton { text: I18n.tr("shortcuts.edit"); symbol: "settings"; enabled: !ShortcutsState.busy && !root.editing; onClicked: root.open(shortcutRow.modelData) }
                AppearanceButton { text: shortcutRow.modelData.enabled ? I18n.tr("shortcuts.delete") : I18n.tr("shortcuts.restore"); symbol: shortcutRow.modelData.enabled ? "close" : "plus"; enabled: !ShortcutsState.busy && !root.editing; onClicked: shortcutRow.modelData.enabled ? ShortcutsState.remove(shortcutRow.modelData.id) : ShortcutsState.edit(Object.assign({}, shortcutRow.modelData, {enabled: true})) }
            }
        }
        Text { anchors.centerIn: parent; visible: !list.count; text: ShortcutsState.loaded ? I18n.tr("shortcuts.no_results") : I18n.tr("shortcuts.loading"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 13 }
    }
    Text { Layout.fillWidth: true; visible: ShortcutsState.external.length > 0 && root.viewMode === "custom" && !root.editing; text: I18n.trWith("shortcuts.external_notice", {count: ShortcutsState.external.length}); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
    RowLayout {
        id: footer
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: root.editing ? I18n.tr("shortcuts.finish_editing_prompt") : ShortcutsState.error || ShortcutsState.message || (ShortcutsState.dirty ? I18n.tr("common.unsaved_changes") : I18n.tr("common.all_saved")); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12; wrapMode: Text.Wrap }
        AppearanceButton { text: I18n.tr("common.cancel"); symbol: "close"; enabled: ShortcutsState.dirty && !ShortcutsState.busy && !root.editing; onClicked: ShortcutsState.cancel() }
        AppearanceButton { text: ShortcutsState.busy ? I18n.tr("shortcuts.validating") : I18n.tr("common.apply"); symbol: "check"; primary: true; enabled: ShortcutsState.dirty && !ShortcutsState.busy && !root.editing; onClicked: ShortcutsState.apply() }
    }
}
