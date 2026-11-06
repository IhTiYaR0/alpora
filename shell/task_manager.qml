//@ pragma AppId poly-shell-task-manager
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QSG_USE_SIMPLE_ANIMATION_DRIVER=1
//@ pragma UseQApplication
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "theme" as PolyTheme

ShellRoot {
    id: root
    property string activeTab: "processes"
    property string searchText: ""
    property int selectedPid: -1
    property string selectedProcessName: ""
    property string selectedServiceName: ""
    property var processesData: []
    property var performanceData: ({})
    property var startupData: []
    property var usersData: []
    property var detailsData: []
    property var servicesData: []
    property var cpuHistory: []
    property var memHistory: []
    property bool refreshing: false
    property string statusMessage: ""

    function show(): void {
        taskWindow.visible = true;
        taskWindow.minimized = false;
        Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({ window = "class:^poly-shell-task-manager$" })' : 'focuswindow class:^poly-shell-task-manager$');
        fetchCurrentTab();
    }

    IpcHandler {
        target: "task-manager-app"
        function raiseWindow(): void { root.show(); }
        function selectTab(tab: string): void { root.activeTab = tab; root.fetchCurrentTab(); }
    }

    function fetchCurrentTab(): void {
        if (root.refreshing) return;
        root.refreshing = true;
        dataFetcher.command = [Session.controller, "tasks", "--tab", root.activeTab];
        dataFetcher.running = true;
    }

    Process {
        id: dataFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (root.activeTab === "processes") root.processesData = parsed;
                    else if (root.activeTab === "performance") {
                        root.performanceData = parsed;
                        const cpuVal = (parsed.cpu && parsed.cpu.percent) ? parsed.cpu.percent : 0;
                        const memVal = (parsed.memory && parsed.memory.percent) ? parsed.memory.percent : 0;
                        const nextCpu = root.cpuHistory.slice(-29);
                        nextCpu.push(cpuVal);
                        root.cpuHistory = nextCpu;
                        const nextMem = root.memHistory.slice(-29);
                        nextMem.push(memVal);
                        root.memHistory = nextMem;
                    }
                    else if (root.activeTab === "startup") root.startupData = parsed;
                    else if (root.activeTab === "users") root.usersData = parsed;
                    else if (root.activeTab === "details") root.detailsData = parsed;
                    else if (root.activeTab === "services") root.servicesData = parsed;
                } catch (_) {}
                root.refreshing = false;
            }
        }
        onExited: root.refreshing = false
    }

    Process {
        id: actionRunner
        onExited: exitCode => {
            root.fetchCurrentTab();
            if (exitCode === 0) root.statusMessage = I18n.tr("common.done");
            else root.statusMessage = I18n.tr("tasks.action_failed");
        }
    }

    function endSelectedProcess(): void {
        if (root.selectedPid <= 1) return;
        actionRunner.command = [Session.controller, "tasks", "--kill", String(root.selectedPid)];
        actionRunner.running = true;
    }

    function toggleStartup(itemPath: string, enabled: bool): void {
        actionRunner.command = [Session.controller, "tasks", "--startup-toggle", itemPath, enabled ? "on" : "off"];
        actionRunner.running = true;
    }

    function serviceAction(unit: string, act: string): void {
        actionRunner.command = [Session.controller, "tasks", "--service", unit, act];
        actionRunner.running = true;
    }

    Timer {
        id: autoRefreshTimer
        interval: 2000
        repeat: true
        running: taskWindow.visible && !taskWindow.minimized
        onTriggered: root.fetchCurrentTab()
    }

    Component.onCompleted: fetchCurrentTab()

    // qmllint disable uncreatable-type
    FloatingWindow {
        // qmllint enable uncreatable-type
        id: taskWindow
        title: "ALPORA Task Manager"
        implicitWidth: 1040; implicitHeight: 700
        minimumSize: Qt.size(880, 560)
        color: "transparent"; visible: true

        Rectangle {
            anchors.fill: parent; radius: Session.visual.barRadius || 14
            gradient: Gradient {
                GradientStop { position: 0; color: Session.surface }
                GradientStop { position: 1; color: Session.background }
            }
            border.width: 1; border.color: Glass.tint(Session.accent, 0.28)
            clip: true

            ColumnLayout {
                anchors.fill: parent; spacing: 0

                // 1. Window Header & Tabs
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 52
                    color: Glass.tint(Session.background, 0.6)
                    border.width: 0; border.color: "transparent"

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 14

                        MouseArea {
                            Layout.preferredWidth: 130; Layout.fillHeight: true
                            onPressed: taskWindow.startSystemMove()
                            Row {
                                anchors.verticalCenter: parent.verticalCenter; spacing: 10
                                GemMark { width: 22; height: 26; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: I18n.tr("tasks.title")
                                    color: Session.foreground; font.family: Session.fontFamily
                                    font.pixelSize: 14; font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Navigation Tabs
                        Row {
                            Layout.fillWidth: true; spacing: 4
                            Repeater {
                                model: [
                                    {key: "processes", label: I18n.tr("tasks.tab_processes")},
                                    {key: "performance", label: I18n.tr("tasks.tab_performance")},
                                    {key: "startup", label: I18n.tr("tasks.tab_startup")},
                                    {key: "users", label: I18n.tr("tasks.tab_users")},
                                    {key: "details", label: I18n.tr("tasks.tab_details")},
                                    {key: "services", label: I18n.tr("tasks.tab_services")}
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: tabText.implicitWidth + 24; height: 34
                                    radius: 7
                                    color: root.activeTab === modelData.key ? Glass.tint(Session.accent, 0.20) : tabMouse.containsMouse ? Glass.tint(Session.accent, 0.08) : "transparent"
                                    border.width: root.activeTab === modelData.key ? 1 : 0
                                    border.color: Glass.tint(Session.accent, 0.4)

                                    Text {
                                        id: tabText
                                        anchors.centerIn: parent
                                        text: parent.modelData.label
                                        color: root.activeTab === parent.modelData.key ? Session.accent : Session.muted
                                        font.family: Session.fontFamily; font.pixelSize: 12; font.weight: root.activeTab === parent.modelData.key ? Font.Medium : Font.Normal
                                    }
                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent; hoverEnabled: true
                                        onClicked: { root.activeTab = parent.modelData.key; root.fetchCurrentTab(); }
                                    }
                                }
                            }
                        }

                        // Search box
                        Rectangle {
                            Layout.preferredWidth: 180; Layout.preferredHeight: 30
                            radius: 6; color: Glass.tint(Session.surface, 0.6)
                            border.width: 1; border.color: searchInput.activeFocus ? Session.accent : Glass.tint(Session.muted, 0.3)

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 4; spacing: 6
                                Icon { name: "search"; width: 14; height: 14; color: Session.muted }
                                TextInput {
                                    id: searchInput
                                    Layout.fillWidth: true
                                    text: root.searchText
                                    color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11
                                    clip: true
                                    onTextChanged: root.searchText = text
                                    Text {
                                        visible: !searchInput.text && !searchInput.activeFocus
                                        text: I18n.tr("tasks.filter_placeholder")
                                        color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Glass.tint(Session.accent, 0.18) }

                // 2. Tab Content Views
                StackLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    currentIndex: root.activeTab === "processes" ? 0
                                : root.activeTab === "performance" ? 1
                                : root.activeTab === "startup" ? 2
                                : root.activeTab === "users" ? 3
                                : root.activeTab === "details" ? 4 : 5

                    // TAB 1: Processes
                    Item {
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 14; spacing: 10
                            // Table header
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 28; radius: 4
                                color: Glass.tint(Session.surface, 0.5)
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                    Text { Layout.fillWidth: true; text: I18n.tr("tasks.col_name"); color: Session.muted; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    Text { Layout.preferredWidth: 70; text: I18n.tr("tasks.col_pid"); color: Session.muted; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    Text { Layout.preferredWidth: 90; text: I18n.tr("tasks.col_status"); color: Session.muted; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    Text { Layout.preferredWidth: 80; text: I18n.tr("tasks.col_cpu"); color: Session.muted; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    Text { Layout.preferredWidth: 90; text: I18n.tr("tasks.col_memory"); color: Session.muted; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    Text { Layout.preferredWidth: 90; text: I18n.tr("tasks.col_user"); color: Session.muted; font.pixelSize: 11; font.weight: Font.DemiBold }
                                }
                            }
                            // Process List
                            ListView {
                                id: processList
                                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 3
                                model: root.processesData.filter(p => !root.searchText || p.name.toLowerCase().includes(root.searchText.toLowerCase()))
                                delegate: Rectangle {
                                    required property var modelData
                                    width: processList.width; height: 34; radius: 5
                                    color: root.selectedPid === modelData.pid ? Glass.tint(Session.accent, 0.22) : pMouse.containsMouse ? Glass.tint(Session.surface, 0.6) : "transparent"
                                    border.width: root.selectedPid === modelData.pid ? 1 : 0
                                    border.color: Glass.tint(Session.accent, 0.45)

                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                        Text { Layout.fillWidth: true; text: parent.modelData.name; color: Session.foreground; font.pixelSize: 12; elide: Text.ElideRight }
                                        Text { Layout.preferredWidth: 70; text: String(parent.modelData.pid); color: Session.muted; font.pixelSize: 11 }
                                        Text { Layout.preferredWidth: 90; text: parent.modelData.status; color: Session.muted; font.pixelSize: 11 }
                                        Text { Layout.preferredWidth: 80; text: parent.modelData.cpu_percent + "%"; color: parent.modelData.cpu_percent > 15 ? Session.accent : Session.foreground; font.pixelSize: 11 }
                                        Text { Layout.preferredWidth: 90; text: parent.modelData.memory_mb + " MB"; color: Session.foreground; font.pixelSize: 11 }
                                        Text { Layout.preferredWidth: 90; text: parent.modelData.user; color: Session.muted; font.pixelSize: 11 }
                                    }
                                    MouseArea {
                                        id: pMouse
                                        anchors.fill: parent; hoverEnabled: true
                                        onClicked: { root.selectedPid = parent.modelData.pid; root.selectedProcessName = parent.modelData.name; }
                                    }
                                }
                            }
                        }
                    }

                    // TAB 2: Performance
                    Item {
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 16; spacing: 16
                            // Left list cards
                            ColumnLayout {
                                Layout.preferredWidth: 260; Layout.fillHeight: true; spacing: 10
                                // CPU Card
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 90; radius: 8
                                    color: Glass.tint(Session.surface, 0.7); border.width: 1; border.color: Glass.tint(Session.accent, 0.3)
                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 12
                                        RowLayout {
                                            Text { text: "CPU"; color: Session.accent; font.pixelSize: 13; font.weight: Font.Bold }
                                            Item { Layout.fillWidth: true }
                                            Text { text: ((root.performanceData.cpu || {}).percent || 0) + "%"; color: Session.foreground; font.pixelSize: 15; font.weight: Font.Bold }
                                        }
                                        Text { text: (root.performanceData.cpu || {}).model || "Processor"; color: Session.muted; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                                    }
                                }
                                // Memory Card
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 90; radius: 8
                                    color: Glass.tint(Session.surface, 0.7); border.width: 1; border.color: Glass.tint(Session.accent, 0.3)
                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 12
                                        RowLayout {
                                            Text { text: I18n.tr("tasks.col_memory"); color: Session.accent; font.pixelSize: 13; font.weight: Font.Bold }
                                            Item { Layout.fillWidth: true }
                                            Text { text: ((root.performanceData.memory || {}).percent || 0) + "%"; color: Session.foreground; font.pixelSize: 15; font.weight: Font.Bold }
                                        }
                                        Text { text: ((root.performanceData.memory || {}).used_mb || 0) + " / " + ((root.performanceData.memory || {}).total_mb || 0) + " MB"; color: Session.muted; font.pixelSize: 11 }
                                    }
                                }
                                Item { Layout.fillHeight: true }
                            }

                            // Right live graph
                            Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true; radius: 8
                                color: Glass.tint(Session.surface, 0.4); border.width: 1; border.color: Glass.tint(Session.accent, 0.2)
                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 16; spacing: 10
                                    Text { text: I18n.tr("tasks.cpu_graph_title"); color: Session.foreground; font.pixelSize: 14; font.weight: Font.DemiBold }
                                    Canvas {
                                        id: perfCanvas
                                        Layout.fillWidth: true; Layout.fillHeight: true
                                        onPaint: {
                                            const ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.strokeStyle = Session.accent;
                                            ctx.lineWidth = 2.5;
                                            const data = root.cpuHistory;
                                            if (data.length < 2) return;
                                            const stepX = width / Math.max(1, data.length - 1);
                                            ctx.beginPath();
                                            for (let i = 0; i < data.length; i++) {
                                                const x = i * stepX;
                                                const y = height - (data[i] / 100.0) * height;
                                                if (i === 0) ctx.moveTo(x, y);
                                                else ctx.lineTo(x, y);
                                            }
                                            ctx.stroke();
                                        }
                                        Connections {
                                            target: root
                                            function onCpuHistoryChanged(): void { perfCanvas.requestPaint(); }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // TAB 3: Startup
                    Item {
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 14; spacing: 10
                            Text { text: I18n.tr("tasks.startup_apps_title"); color: Session.foreground; font.pixelSize: 13; font.weight: Font.DemiBold }
                            ListView {
                                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
                                model: root.startupData
                                delegate: Rectangle {
                                    required property var modelData
                                    width: parent.width; height: 46; radius: 6
                                    color: Glass.tint(Session.surface, 0.6)
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                                        Column {
                                            Layout.fillWidth: true
                                            Text { text: parent.parent.modelData.name; color: Session.foreground; font.pixelSize: 12; font.weight: Font.Medium }
                                            Text { text: parent.parent.modelData.command || parent.parent.modelData.path; color: Session.muted; font.pixelSize: 10; elide: Text.ElideRight }
                                        }
                                        Button {
                                            text: parent.parent.modelData.enabled ? I18n.tr("common.enable") : I18n.tr("common.disable")
                                            onClicked: root.toggleStartup(parent.parent.modelData.path, !parent.parent.modelData.enabled)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // TAB 4: Users
                    Item {
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16; spacing: 12
                            Text { text: I18n.tr("tasks.users_title"); color: Session.foreground; font.pixelSize: 14; font.weight: Font.DemiBold }
                            ListView {
                                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8
                                model: root.usersData
                                delegate: Rectangle {
                                    required property var modelData
                                    width: parent.width; height: 60; radius: 8
                                    color: Glass.tint(Session.surface, 0.6)
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 14; spacing: 14
                                        Rectangle { width: 32; height: 32; radius: 16; color: Glass.tint(Session.accent, 0.2) }
                                        Column {
                                            Layout.fillWidth: true
                                            Text { text: parent.parent.modelData.user; color: Session.foreground; font.pixelSize: 13; font.weight: Font.DemiBold }
                                            Text { text: I18n.trWith("tasks.session_info", {type: parent.parent.modelData.session_type, desktop: parent.parent.modelData.desktop, count: parent.parent.modelData.process_count}); color: Session.muted; font.pixelSize: 11 }
                                        }
                                        Text { text: parent.parent.modelData.memory_mb + " MB RAM"; color: Session.accent; font.pixelSize: 13; font.weight: Font.Medium }
                                    }
                                }
                            }
                        }
                    }

                    // TAB 5: Details
                    Item {
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 14; spacing: 10
                            ListView {
                                id: detailsList
                                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 3
                                model: root.detailsData.filter(d => !root.searchText || d.name.toLowerCase().includes(root.searchText.toLowerCase()))
                                delegate: Rectangle {
                                    required property var modelData
                                    width: detailsList.width; height: 32; radius: 4
                                    color: root.selectedPid === modelData.pid ? Glass.tint(Session.accent, 0.22) : dMouse.containsMouse ? Glass.tint(Session.surface, 0.5) : "transparent"
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                        Text { Layout.preferredWidth: 60; text: String(parent.modelData.pid); color: Session.muted; font.pixelSize: 11 }
                                        Text { Layout.fillWidth: true; text: parent.modelData.name; color: Session.foreground; font.pixelSize: 11 }
                                        Text { Layout.preferredWidth: 80; text: parent.modelData.user; color: Session.muted; font.pixelSize: 11 }
                                        Text { Layout.preferredWidth: 60; text: parent.modelData.cpu_percent + "%"; color: Session.accent; font.pixelSize: 11 }
                                        Text { Layout.preferredWidth: 80; text: parent.modelData.rss_mb + " MB"; color: Session.foreground; font.pixelSize: 11 }
                                        Text { Layout.preferredWidth: 60; text: String(parent.modelData.threads); color: Session.muted; font.pixelSize: 11 }
                                    }
                                    MouseArea {
                                        id: dMouse
                                        anchors.fill: parent; hoverEnabled: true
                                        onClicked: { root.selectedPid = parent.modelData.pid; root.selectedProcessName = parent.modelData.name; }
                                    }
                                }
                            }
                        }
                    }

                    // TAB 6: Services
                    Item {
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 14; spacing: 10
                            ListView {
                                id: serviceList
                                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                                model: root.servicesData.filter(s => !root.searchText || s.unit.toLowerCase().includes(root.searchText.toLowerCase()))
                                delegate: Rectangle {
                                    required property var modelData
                                    width: serviceList.width; height: 42; radius: 5
                                    color: Glass.tint(Session.surface, 0.6)
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                        Rectangle {
                                            width: 8; height: 8; radius: 4
                                            color: parent.parent.modelData.running ? Session.accent : Session.muted
                                        }
                                        Column {
                                            Layout.fillWidth: true
                                            Text { text: parent.parent.modelData.unit; color: Session.foreground; font.pixelSize: 12; font.weight: Font.Medium }
                                            Text { text: parent.parent.modelData.description; color: Session.muted; font.pixelSize: 10; elide: Text.ElideRight }
                                        }
                                        Button {
                                            text: I18n.tr("common.restart")
                                            onClicked: root.serviceAction(parent.parent.modelData.unit, "restart")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Bottom Action Footer
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 46
                    color: Glass.tint(Session.background, 0.8)
                    border.width: 1; border.color: Glass.tint(Session.accent, 0.15)

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        Text {
                            text: root.selectedPid > 1 ? I18n.trWith("tasks.selected_process", {name: root.selectedProcessName, pid: root.selectedPid}) : I18n.trWith("tasks.running_processes_count", {count: root.processesData.length})
                            color: Session.muted; font.pixelSize: 12
                        }
                        Item { Layout.fillWidth: true }
                        Button {
                            visible: root.activeTab === "processes" || root.activeTab === "details"
                            enabled: root.selectedPid > 1
                            text: I18n.tr("tasks.end_task")
                            onClicked: root.endSelectedProcess()
                        }
                    }
                }
            }
        }
    }
}
