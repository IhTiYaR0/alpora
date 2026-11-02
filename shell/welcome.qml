//@ pragma AppId poly-shell-welcome
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QSG_USE_SIMPLE_ANIMATION_DRIVER=1
//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import "theme" as PolyTheme
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: root

    property string currentTab: "shortcuts"
    property bool dontShowAgain: false

    function close(): void {
        if (dontShowAgain) {
            dismissWriter.running = true;
        }
        welcomeWindow.visible = false;
        welcomeWindow.close();
        Qt.quit();
    }

    function show(): void {
        welcomeWindow.visible = true;
        welcomeWindow.minimized = false;
        Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({ window = "class:^poly-shell-welcome$" })' : 'focuswindow class:^poly-shell-welcome$');
    }

    IpcHandler {
        target: "welcome-app"
        function raiseWindow(): void { root.show(); }
        function close(): void { root.close(); }
    }

    Process {
        id: dismissWriter
        command: ["bash", "-c", "mkdir -p ~/.local/state/poly-shell && touch ~/.local/state/poly-shell/welcome-dismissed"]
    }

    Process {
        id: fcitxRestart
        command: ["fcitx5", "-d", "--replace"]
    }

    FloatingWindow {
        id: welcomeWindow
        title: "ALPORA Desktop Environment - Chào mừng"
        implicitWidth: 840
        implicitHeight: 560
        minimumSize: Qt.size(800, 520)
        color: "transparent"
        visible: true

        Shortcut { sequence: "Escape"; onActivated: root.close() }

        Rectangle {
            id: container
            anchors.fill: parent
            radius: Math.min(20, Session.visual.panelRadius)
            color: Glass.tint(Session.surface, 0.94)
            border.width: Session.visual.panelBorder
            border.color: Glass.tint(Session.accent, 0.35)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    FacetedMark {
                        width: 40
                        height: 40
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Chào mừng đến với ALPORA"
                            color: Session.foreground
                            font.family: Session.fontFamily
                            font.pixelSize: 20
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "Hệ thống máy tính Arch Linux · Quickshell · Wayland · Vietnamese Native IME"
                            color: Session.muted
                            font.family: Session.fontFamily
                            font.pixelSize: 12
                        }
                    }

                    Button {
                        text: "✕"
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        onClicked: root.close()
                        background: Rectangle {
                            radius: 16
                            color: parent.hovered ? Glass.tint(Session.accent, 0.25) : Glass.tint(Session.foreground, 0.08)
                        }
                        contentItem: Text {
                            text: "✕"
                            color: Session.foreground
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                        }
                    }
                }

                // Tab Switcher
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { id: "shortcuts", label: "Phím tắt cốt lõi" },
                            { id: "ime", label: "Gõ Tiếng Việt" },
                            { id: "themes", label: "Giao diện & Chế độ" },
                            { id: "doctor", label: "Tình trạng hệ thống" }
                        ]

                        Button {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            checkable: true
                            checked: root.currentTab === modelData.id
                            onClicked: root.currentTab = modelData.id

                            background: Rectangle {
                                radius: 8
                                color: checked ? Session.accent : (parent.hovered ? Glass.tint(Session.foreground, 0.1) : Glass.tint(Session.foreground, 0.04))
                                border.width: checked ? 0 : 1
                                border.color: Glass.tint(Session.foreground, 0.1)
                            }

                            contentItem: Text {
                                text: modelData.label
                                color: checked ? Session.surface : Session.foreground
                                font.family: Session.fontFamily
                                font.pixelSize: 12
                                font.weight: checked ? Font.DemiBold : Font.Normal
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // Content Area
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Glass.tint(Session.surface, 0.5)
                    border.width: 1
                    border.color: Glass.tint(Session.foreground, 0.08)
                    clip: true

                    // 1. Tab Shortcuts
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 16
                        visible: root.currentTab === "shortcuts"
                        contentWidth: availableWidth

                        ColumnLayout {
                            width: parent.width
                            spacing: 10

                            Repeater {
                                model: [
                                    { key: "Super + Space", desc: "Mở Spotlight Launcher & Omni-Bar (Tìm app, tính toán, tra từ, web)" },
                                    { key: "Super + V", desc: "Mở lịch sử Clipboard & Quản lý khay nhớ tạm" },
                                    { key: "Super + I", desc: "Mở Quick Settings Control Center (Wi-Fi, Bluetooth, Âm lượng, Độ sáng)" },
                                    { key: "Super + ~", desc: "Mở Quake Dropdown Terminal (Cửa sổ terminal trượt từ trên xuống)" },
                                    { key: "Super + Return", desc: "Mở Terminal tiêu chuẩn (Foot / Kitty)" },
                                    { key: "Super + E", desc: "Mở Trình quản lý tệp Nautilus" },
                                    { key: "Super + Tab", desc: "Mở Workspace & Window Overview toàn cảnh" },
                                    { key: "Super + W", desc: "Chuyển đổi tức thì chế độ Work Mode và Vibe Mode" },
                                    { key: "Super + Q", desc: "Đóng cửa sổ đang chọn" },
                                    { key: "Super + Shift + S", desc: "Chụp ảnh màn hình (Chọn vùng, cửa sổ hoặc toàn bộ)" }
                                ]

                                Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    radius: 8
                                    color: Glass.tint(Session.surface, 0.6)
                                    border.width: 1
                                    border.color: Glass.tint(Session.foreground, 0.06)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 12

                                        Rectangle {
                                            radius: 6
                                            color: Glass.tint(Session.accent, 0.22)
                                            Layout.preferredWidth: 160
                                            Layout.preferredHeight: 26

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.key
                                                color: Session.accent
                                                font.family: "monospace"
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.desc
                                            color: Session.foreground
                                            font.family: Session.fontFamily
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. Tab IME
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 16
                        visible: root.currentTab === "ime"

                        Text {
                            text: "Bộ gõ Tiếng Việt Fcitx5 Bamboo"
                            color: Session.foreground
                            font.family: Session.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "ALPORA tích hợp sẵn Fcitx5 với bộ gõ Bamboo tối ưu cho Wayland và Qt/GTK. Nhấn Ctrl + Space để bật/tắt gõ Tiếng Việt."
                            color: Session.muted
                            font.family: Session.fontFamily
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // Test input box
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            radius: 10
                            color: Glass.tint(Session.surface, 0.8)
                            border.width: 1
                            border.color: Session.accent

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Text {
                                    text: "Thử gõ:"
                                    color: Session.muted
                                    font.family: Session.fontFamily
                                    font.pixelSize: 12
                                }

                                TextField {
                                    id: testField
                                    Layout.fillWidth: true
                                    placeholderText: "Nhập chữ Tiếng Việt tại đây để kiểm tra (ví dụ: Cộng hòa Xã hội Chủ nghĩa Việt Nam)..."
                                    color: Session.foreground
                                    font.family: Session.fontFamily
                                    font.pixelSize: 13
                                    background: Item {}
                                }
                            }
                        }

                        RowLayout {
                            spacing: 12

                            Button {
                                text: "Khởi động lại Fcitx5 Bamboo"
                                Layout.preferredHeight: 36
                                onClicked: fcitxRestart.running = true
                                background: Rectangle {
                                    radius: 8
                                    color: parent.hovered ? Glass.tint(Session.accent, 0.3) : Glass.tint(Session.foreground, 0.1)
                                    border.width: 1
                                    border.color: Glass.tint(Session.accent, 0.4)
                                }
                                contentItem: Text {
                                    text: "Khởi động lại Fcitx5 Bamboo"
                                    color: Session.accent
                                    font.family: Session.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Text {
                                text: fcitxRestart.running ? "Đang khởi động..." : "Sẵn sàng"
                                color: Session.muted
                                font.family: Session.fontFamily
                                font.pixelSize: 11
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // 3. Tab Themes
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14
                        visible: root.currentTab === "themes"

                        Text {
                            text: "Chủ đề & Trạng thái làm việc"
                            color: Session.foreground
                            font.family: Session.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }

                        RowLayout {
                            spacing: 12

                            Button {
                                text: "Chuyển Work / Vibe Mode (Hiện tại: " + Session.mode + ")"
                                Layout.preferredHeight: 36
                                onClicked: Session.setMode("toggle")
                                background: Rectangle {
                                    radius: 8
                                    color: Glass.tint(Session.accent, 0.25)
                                    border.width: 1
                                    border.color: Session.accent
                                }
                                contentItem: Text {
                                    text: "Chuyển Work / Vibe Mode (" + Session.mode.toUpperCase() + ")"
                                    color: Session.accent
                                    font.family: Session.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        Text {
                            text: "Bộ sưu tập phong cảnh thích ứng tự động:"
                            color: Session.muted
                            font.family: Session.fontFamily
                            font.pixelSize: 12
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Repeater {
                                model: [
                                    { id: "alpine", name: "Alpine Sage" },
                                    { id: "moon-lake", name: "Moon Lake" },
                                    { id: "forest-mist", name: "Forest Mist" },
                                    { id: "warm-desert", name: "Warm Desert" },
                                    { id: "timeline", name: "Timeline Auto-Chrono" }
                                ]

                                Button {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 45
                                    onClicked: ThemeState.applyTheme(modelData.id)

                                    background: Rectangle {
                                        radius: 8
                                        color: Glass.tint(Session.surface, 0.8)
                                        border.width: 1
                                        border.color: parent.hovered ? Session.accent : Glass.tint(Session.foreground, 0.12)
                                    }

                                    contentItem: Text {
                                        text: modelData.name
                                        color: Session.foreground
                                        font.family: Session.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // 4. Tab Doctor & Health
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12
                        visible: root.currentTab === "doctor"

                        Text {
                            text: "Kiểm tra sức khỏe hệ thống (System Doctor)"
                            color: Session.foreground
                            font.family: Session.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 8
                                color: Glass.tint(Session.surface, 0.7)
                                border.width: 1
                                border.color: Glass.tint(Session.foreground, 0.08)

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "Compositor"; color: Session.muted; font.pixelSize: 11 }
                                    Text { text: "Hyprland (Wayland)"; color: Session.foreground; font.pixelSize: 13; font.weight: Font.DemiBold }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 8
                                color: Glass.tint(Session.surface, 0.7)
                                border.width: 1
                                border.color: Glass.tint(Session.foreground, 0.08)

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "Giao diện Shell"; color: Session.muted; font.pixelSize: 11 }
                                    Text { text: "Quickshell Qt6"; color: Session.foreground; font.pixelSize: 13; font.weight: Font.DemiBold }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 8
                                color: Glass.tint(Session.surface, 0.7)
                                border.width: 1
                                border.color: Glass.tint(Session.foreground, 0.08)

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "Âm thanh & Multimedia"; color: Session.muted; font.pixelSize: 11 }
                                    Text { text: "PipeWire / WirePlumber"; color: Session.foreground; font.pixelSize: 13; font.weight: Font.DemiBold }
                                }
                            }
                        }

                        RowLayout {
                            spacing: 12

                            Button {
                                text: "Mở ALPORA Settings (Cài đặt đầy đủ)"
                                Layout.preferredHeight: 36
                                onClicked: {
                                    Quickshell.execDetached([Session.controller, "settings"]);
                                    root.close();
                                }
                                background: Rectangle {
                                    radius: 8
                                    color: Glass.tint(Session.accent, 0.25)
                                    border.width: 1
                                    border.color: Session.accent
                                }
                                contentItem: Text {
                                    text: "Mở ALPORA Settings"
                                    color: Session.accent
                                    font.family: Session.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Button {
                                text: "Mở Task Manager"
                                Layout.preferredHeight: 36
                                onClicked: {
                                    Quickshell.execDetached([Session.controller, "task-manager"]);
                                }
                                background: Rectangle {
                                    radius: 8
                                    color: Glass.tint(Session.foreground, 0.08)
                                    border.width: 1
                                    border.color: Glass.tint(Session.foreground, 0.15)
                                }
                                contentItem: Text {
                                    text: "Mở Mini Task Manager"
                                    color: Session.foreground
                                    font.family: Session.fontFamily
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // Footer
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    CheckBox {
                        id: checkDontShow
                        text: "Không hiển thị lại cửa sổ này khi khởi động"
                        checked: root.dontShowAgain
                        onCheckedChanged: root.dontShowAgain = checked
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Bắt đầu trải nghiệm"
                        Layout.preferredHeight: 38
                        Layout.preferredWidth: 160
                        onClicked: root.close()
                        background: Rectangle {
                            radius: 8
                            color: Session.accent
                        }
                        contentItem: Text {
                            text: "Bắt đầu trải nghiệm"
                            color: Session.surface
                            font.family: Session.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
