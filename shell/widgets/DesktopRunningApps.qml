pragma ComponentBehavior: Bound
import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

DesktopWidgetCard {
    id: root
    implicitWidth: expanded ? 540 : 390
    implicitHeight: expanded ? 620 : 360
    clip: true

    property var clients: []
    property var processes: []
    property string errorText: ""
    property string activeTab: "apps"
    property string processQuery: ""
    property string pendingProcessKey: ""
    property string forceProcessKey: ""
    property string requestedSignal: ""
    property bool terminationGraceElapsed: false
    readonly property bool expanded: RunningAppsState.expanded
    readonly property var windows: clients.filter(client => client && client.address && client.mapped
        && !client.hidden && Number(client.pid) > 1
        && (client.class || client.initialClass || client.appId || client.title || client.initialTitle))
    readonly property var apps: buildApps()
    readonly property var filteredProcesses: processes.filter(proc => {
        const q = processQuery.trim().toLocaleLowerCase();
        return !q || (String(proc.name || "") + " " + String(proc.command || "") + " "
            + String(proc.pid) + " " + String(proc.ppid) + " " + String(proc.appName || ""))
            .toLocaleLowerCase().includes(q);
    })

    function tr(key: string): string {
        const m = {
            title: {en:"Running apps", es:"Aplicaciones en ejecución", ru:"Запущенные приложения", vi:"Ứng dụng đang chạy"},
            apps: {en:"Applications", es:"Aplicaciones", ru:"Приложения", vi:"Ứng dụng"},
            processes: {en:"Processes", es:"Procesos", ru:"Процессы", vi:"Tiến trình"},
            details: {en:"Details", es:"Detalles", ru:"Подробнее", vi:"Chi tiết"},
            more: {en:"more", es:"más", ru:"ещё", vi:"thêm"},
            collapse: {en:"Compact view", es:"Vista compacta", ru:"Свернуть", vi:"Thu gọn"},
            refresh: {en:"Refresh", es:"Actualizar", ru:"Обновить", vi:"Làm mới"},
            noWindows: {en:"No apps with open windows", es:"No hay aplicaciones con ventanas abiertas", ru:"Нет приложений с открытыми окнами", vi:"Không có ứng dụng nào mở cửa sổ"},
            noProcesses: {en:"No user processes found", es:"No se encontraron procesos del usuario", ru:"Пользовательские процессы не найдены", vi:"Không tìm thấy tiến trình người dùng"},
            noApps: {en:"No windowed applications found", es:"No se encontraron aplicaciones con ventanas", ru:"Приложения с окнами не найдены", vi:"Không tìm thấy ứng dụng có cửa sổ"},
            untitled: {en:"Untitled window", es:"Ventana sin título", ru:"Окно без названия", vi:"Cửa sổ chưa đặt tên"},
            windows: {en:"windows", es:"ventanas", ru:"окон", vi:"cửa sổ"},
            oneWindow: {en:"window", es:"ventana", ru:"окно", vi:"cửa sổ"},
            closeWindow: {en:"Close window", es:"Cerrar ventana", ru:"Закрыть окно", vi:"Đóng cửa sổ"},
            endApp: {en:"End app process", es:"Finalizar proceso de la app", ru:"Завершить процесс приложения", vi:"Dừng ứng dụng"},
            endingApp: {en:"Ending…", es:"Finalizando…", ru:"Завершение…", vi:"Đang dừng…"},
            endProcess: {en:"End process", es:"Finalizar proceso", ru:"Завершить процесс", vi:"Dừng tiến trình"},
            forceKill: {en:"Force kill", es:"Forzar cierre", ru:"Завершить принудительно", vi:"Buộc dừng"},
            protected: {en:"Protected session process", es:"Proceso de sesión protegido", ru:"Защищённый процесс сеанса", vi:"Tiến trình phiên được bảo vệ"},
            pid: {en:"PID", es:"PID", ru:"PID", vi:"PID"},
            ppid: {en:"Parent", es:"Padre", ru:"Родитель", vi:"Tiến trình cha"},
            command: {en:"Command", es:"Comando", ru:"Команда", vi:"Lệnh"},
            associated: {en:"App", es:"Aplicación", ru:"Приложение", vi:"Ứng dụng"},
            background: {en:"No matching open window (background process)", es:"Sin ventana asociada (proceso en segundo plano)", ru:"Нет связанного окна (фоновый процесс)", vi:"Không có cửa sổ mở (tiến trình nền)"},
            mainProcess: {en:"Main app process", es:"Proceso principal de la app", ru:"Основной процесс приложения", vi:"Tiến trình chính của ứng dụng"},
            ownsWindow: {en:"Owns a window", es:"Gestiona una ventana", ru:"Владеет окном", vi:"Sở hữu cửa sổ"},
            childProcess: {en:"Child process", es:"Proceso hijo", ru:"Дочерний процесс", vi:"Tiến trình con"},
            renderer: {en:"Renderer subprocess", es:"Subproceso de renderizado", ru:"Процесс отрисовки", vi:"Tiến trình kết xuất (renderer)"},
            gpuProcess: {en:"GPU subprocess", es:"Subproceso de GPU", ru:"Процесс GPU", vi:"Tiến trình GPU"},
            utilityProcess: {en:"Utility subprocess", es:"Subproceso auxiliar", ru:"Вспомогательный процесс", vi:"Tiến trình tiện ích"},
            zygoteProcess: {en:"Zygote subprocess", es:"Subproceso zygote", ru:"Процесс zygote", vi:"Tiến trình Zygote"},
            contentProcess: {en:"Content subprocess", es:"Subproceso de contenido", ru:"Процесс содержимого", vi:"Tiến trình nội dung"},
            backgroundProcess: {en:"Background process", es:"Proceso en segundo plano", ru:"Фоновый процесс", vi:"Tiến trình chạy ngầm"},
            mappedTree: {en:"Matched through the process tree", es:"Asociado por el árbol de procesos", ru:"Связан через дерево процессов", vi:"Khớp theo cây tiến trình"},
            matchedName: {en:"Likely match by app/process name", es:"Posible coincidencia por nombre", ru:"Вероятное совпадение по имени", vi:"Khớp theo tên ứng dụng/tiến trình"},
            mappedWindow: {en:"Matched by window PID", es:"Asociado por el PID de la ventana", ru:"Связан по PID окна", vi:"Khớp theo PID cửa sổ"},
            filterProcesses: {en:"Filter by name, PID or command…", es:"Filtrar por nombre, PID o comando…", ru:"Фильтр по имени, PID или команде…", vi:"Lọc theo tên, PID hoặc lệnh…"},
            detailsHint: {en:"Open Details to inspect the app's process tree and background processes.", es:"Abre Detalles para explorar el árbol de procesos de cada app y los procesos en segundo plano.", ru:"Откройте подробности, чтобы изучить дерево процессов приложения и фоновые процессы.", vi:"Mở Chi tiết để kiểm tra cây tiến trình và các tiến trình chạy ngầm của ứng dụng."},
            mappingHint: {en:"Mappings are inferred. A process shown as background has no confidently matched open window.", es:"Las asociaciones son estimaciones. Un proceso en segundo plano no tiene una ventana asociada con suficiente confianza.", ru:"Связи определяются автоматически. У фонового процесса нет надёжно сопоставленного открытого окна.", vi:"Liên kết chỉ mang tính suy đoán. Tiến trình ngầm không có cửa sổ mở tương ứng đáng tin cậy."},
            readError: {en:"Could not read windows or processes", es:"No se pudieron leer las ventanas o los procesos", ru:"Не удалось прочитать окна или процессы", vi:"Không thể đọc danh sách cửa sổ hoặc tiến trình"},
            endError: {en:"Could not end process", es:"No se pudo finalizar el proceso", ru:"Не удалось завершить процесс", vi:"Không thể dừng tiến trình"},
            closeError: {en:"Could not request window close", es:"No se pudo solicitar el cierre de la ventana", ru:"Не удалось запросить закрытие окна", vi:"Không thể yêu cầu đóng cửa sổ"},
            forceWarning: {en:"Force kill cannot save data and may close every window belonging to that process.", es:"El cierre forzado no guarda datos y puede cerrar todas las ventanas de ese proceso.", ru:"Принудительное завершение не сохраняет данные и может закрыть все окна этого процесса.", vi:"Buộc dừng sẽ không lưu dữ liệu và có thể đóng mọi cửa sổ thuộc tiến trình này."}
        };
        const item = m[key];
        const lang = I18n.locale || I18n.language || "en";
        return item ? (item[lang] || item.en) : key;
    }
    function appIdentity(client: var): string {
        return String(client.class || client.initialClass || client.appId || "application");
    }
    function isAlporaSettings(client: var): bool {
        const ids = [client.class, client.initialClass, client.appId]
            .map(value => String(value || "")).join(" ").toLocaleLowerCase();
        const title = String(client.title || client.initialTitle || "");
        return ids.includes("poly-shell-settings") || ids.includes("alpora-settings")
            || /^(?:Ajustes|Settings|Настройки)\s*[·—-]\s*ALPORA$/i.test(title);
    }
    function appKey(client: var): string {
        return appIdentity(client).toLocaleLowerCase().replace(/[^a-z0-9]+/g, "");
    }
    function appName(client: var): string {
        const raw = appIdentity(client);
        if (isAlporaSettings(client)) return I18n.tr("Settings");
        // Desktop IDs often look like org.mozilla.firefox; show the recognizable final segment.
        if (/^[A-Za-z0-9_.:/-]+$/.test(raw) && /[.:/_-]/.test(raw)) {
            const parts = raw.split(/[.:/_-]+/).filter(part => part.length);
            if (parts.length) {
                const last = parts[parts.length - 1];
                return last.charAt(0).toLocaleUpperCase() + last.slice(1);
            }
        }
        return raw;
    }
    function windowTitle(client: var): string {
        const title = String(client.title || client.initialTitle || "");
        if (isAlporaSettings(client)) return I18n.tr("Settings") + " · ALPORA";
        return title && title !== appIdentity(client) && title !== appName(client) ? title : tr("untitled");
    }
    function buildApps(): var {
        const groups = [];
        for (const client of windows) {
            const key = appKey(client);
            let group = groups.find(item => item.key === key);
            if (!group) {
                group = {key: key, name: appName(client), windows: []};
                groups.push(group);
            }
            group.windows.push(client);
        }
        groups.sort((a, b) => a.name.localeCompare(b.name));
        return groups;
    }
    function processKey(proc: var): string { return String(proc.pid) + ":" + String(proc.startTicks); }
    function processForApp(app: var): var {
        let proc = processes.find(p => p.appKey === app.key && p.appRoot);
        if (!proc) {
            const ids = app.windows.map(w => Number(w.pid));
            proc = processes.find(p => ids.includes(Number(p.pid)));
        }
        return proc || null;
    }
    function appForceReady(app: var): bool {
        const proc = processForApp(app);
        return !!proc && !!forceProcessKey && forceProcessKey === processKey(proc);
    }
    function appActionLabel(app: var): string {
        const proc = processForApp(app);
        if (!proc) return tr("endApp");
        const key = processKey(proc);
        return pendingProcessKey === key ? "…" : (forceProcessKey === key ? tr("forceKill") : tr("endApp"));
    }
    function compactActionLabel(app: var): string {
        return tr("closeWindow");
    }
    function compactActionText(app: var): string {
        return "×";
    }
    function compactActionEnabled(app: var): bool {
        if (!app || !app.windows || app.windows.length === 0) return false;
        // The preview represents the first window title, so its close action targets
        // that window only. Other windows of the same application remain open.
        const address = String(app.windows[0].address || "");
        return /^0x[0-9a-fA-F]+$/.test(address);
    }
    function compactAppAction(app: var): void {
        if (!app || !app.windows || app.windows.length === 0) return;
        const client = app.windows[0];
        // Normal close request: let the app save state or ask about unsaved changes.
        closeWindow(String(client.address || ""));
    }
    function processRoleLabel(proc: var): string {
        const roles = {main:"mainProcess", window:"ownsWindow", child:"childProcess", renderer:"renderer",
            gpu:"gpuProcess", utility:"utilityProcess", zygote:"zygoteProcess", content:"contentProcess", background:"backgroundProcess"};
        return tr(roles[proc.role] || "backgroundProcess");
    }
    function associationLabel(proc: var): string {
        if (!proc.appName) return tr("background");
        let mapping = proc.associationMethod === "name-match" ? tr("matchedName")
            : proc.associationMethod === "window-pid" ? tr("mappedWindow") : tr("mappedTree");
        return tr("associated") + ": " + proc.appName + " · " + processRoleLabel(proc) + " · " + mapping;
    }
    function countLabel(): string {
        const appCount = apps.length;
        const windowCount = windows.length;
        const lang = I18n.locale || I18n.language || "en";
        if (lang === "vi") return appCount + " ứng dụng · " + windowCount + " cửa sổ";
        if (lang === "es") return appCount + (appCount === 1 ? " aplicación" : " aplicaciones") + " · " + windowCount + (windowCount === 1 ? " ventana" : " ventanas");
        if (lang === "ru") return appCount + " прил. · " + windowCount + " " + (windowCount % 10 === 1 && windowCount % 100 !== 11 ? "окно" : windowCount % 10 >= 2 && windowCount % 10 <= 4 && (windowCount % 100 < 12 || windowCount % 100 > 14) ? "окна" : "окон");
        return appCount + (appCount === 1 ? " app" : " apps") + " · " + windowCount + (windowCount === 1 ? " window" : " windows");
    }
    function refresh(): void {
        if (Hyprland.toplevels && Hyprland.toplevels.values && Hyprland.toplevels.values.length > 0) {
            root.clients = Hyprland.toplevels.values.map(t => t.lastIpcObject).filter(c => !!c);
            root.errorText = "";
            root.refreshProcesses();
            return;
        }
        if (!clientReader.running) clientReader.running = true;
    }
    function refreshProcesses(): void {
        if (processReader.running) return;
        const refs = windows.map(w => ({pid: Number(w.pid), appClass: appIdentity(w), appName: appName(w)}));
        processReader.command = [Session.controller, "running-apps", "snapshot", JSON.stringify(refs)];
        processReader.running = true;
    }
    function closeWindow(address: string): void {
        if (!/^0x[0-9a-fA-F]+$/.test(String(address || ""))) return;
        errorText = "";
        Hyprland.dispatch(Hyprland.usingLua
            ? 'hl.dsp.window.close({window="address:' + address + '"})'
            : 'closewindow address:' + address);
        refreshDelay.restart();
    }
    function requestSignal(proc: var, force: bool): void {
        if (!proc || !proc.canSignal || terminator.running) return;
        const key = processKey(proc);
        if (force && key !== forceProcessKey) return;
        pendingProcessKey = key;
        forceProcessKey = "";
        terminationGraceElapsed = false;
        errorText = "";
        requestedSignal = force ? "KILL" : "TERM";
        terminator.command = [Session.controller, "running-apps",
            "signal", String(proc.pid), String(proc.startTicks), requestedSignal];
        terminator.running = true;
    }
    function toggleExpanded(): void {
        RunningAppsState.expanded = !RunningAppsState.expanded;
        if (RunningAppsState.expanded) refresh();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (/^(openwindow|closewindow|movewindow|activewindow|workspace|focusedmon|windowtitle|windowtitlev2|configreloaded)/.test(event.name))
                refreshDebounce.restart();
        }
    }
    Timer { id: refreshDebounce; interval: 180; onTriggered: root.refresh() }
    Timer { id: refreshDelay; interval: 240; onTriggered: { root.refresh(); root.refreshProcesses(); } }
    Timer { id: processRefresh; interval: 2500; repeat: true; running: root.expanded; onTriggered: { root.refresh(); root.refreshProcesses(); } }
    Timer { id: terminationGrace; interval: 1400; onTriggered: { root.terminationGraceElapsed = true; root.refreshProcesses(); } }

    Process {
        id: clientReader
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text);
                    if (!Array.isArray(next)) throw new Error("Unexpected clients response");
                    root.clients = next;
                    root.errorText = "";
                    root.refreshProcesses();
                } catch (_) { root.errorText = root.tr("readError"); }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.errorText = text.trim() }
        onExited: (exitCode, exitStatus) => {
            if ((exitCode !== 0 || exitStatus !== 0) && !root.errorText) root.errorText = root.tr("readError");
        }
    }
    Process {
        id: processReader
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (!data.ok) throw new Error(data.error || "snapshot failed");
                    root.processes = data.processes || [];
                    root.errorText = "";
                    if (root.pendingProcessKey) {
                        const stillPresent = root.processes.some(p => root.processKey(p) === root.pendingProcessKey);
                        if (!stillPresent) {
                            root.pendingProcessKey = ""; root.forceProcessKey = "";
                            root.terminationGraceElapsed = false; terminationGrace.stop();
                        } else if (root.terminationGraceElapsed && !terminator.running) {
                            root.forceProcessKey = root.pendingProcessKey; root.pendingProcessKey = "";
                            root.terminationGraceElapsed = false; terminationGrace.stop();
                        }
                    }
                } catch (_) { root.errorText = root.tr("readError"); }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.errorText = text.trim() }
    }
    Process {
        id: terminator
        command: []
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.errorText = text.trim() }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0) {
                root.pendingProcessKey = ""; root.forceProcessKey = "";
                terminationGrace.stop(); root.errorText = root.tr("endError"); root.refreshDelay.restart();
            } else if (root.requestedSignal === "TERM") {
                root.terminationGraceElapsed = false;
                terminationGrace.restart();
                root.refreshDelay.restart();
            } else {
                root.pendingProcessKey = ""; root.forceProcessKey = "";
                terminationGrace.stop(); root.refreshDelay.restart();
            }
        }
    }
    Component.onCompleted: refreshDebounce.start()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 13
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 9
                color: Glass.tint(Session.accent, 0.16)
                Icon { anchors.centerIn: parent; name: "monitor"; width: 19; height: 19 }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { text: root.tr("title"); color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                Text { text: root.countLabel(); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
            }
            ToolButton {
                text: reader.running || processReader.running ? "…" : "↻"
                Accessible.name: root.tr("refresh")
                onClicked: { root.refresh(); root.refreshProcesses(); }
            }
            ToolButton {
                text: root.expanded ? "▴" : "↗"
                Accessible.name: root.expanded ? root.tr("collapse") : root.tr("details")
                onClicked: root.toggleExpanded()
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Session.accent; opacity: 0.18 }
        Text {
            visible: !!root.errorText; Layout.fillWidth: true; text: root.errorText
            color: "#e8a2a2"; font.family: Session.fontFamily; font.pixelSize: 10; wrapMode: Text.Wrap
        }

        // Compact preview: only applications that currently own at least one open window.
        ColumnLayout {
            visible: !root.expanded
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
            Text { visible: !root.apps.length && !root.errorText; Layout.fillWidth: true; Layout.fillHeight: true; text: root.tr("noWindows"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; wrapMode: Text.Wrap }
            Repeater {
                model: root.apps.slice(0, 4)
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 49; radius: 8
                    color: Glass.tint(Session.surface, 0.68)
                    border.width: 1; border.color: Glass.tint(Session.accent, 0.12)
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 8
                        Icon { name: "app-window"; Layout.preferredWidth: 17; Layout.preferredHeight: 17 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: modelData.name; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: root.windowTitle(modelData.windows[0]); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        Text { text: String(modelData.windows.length) + "×"; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 }
                        ToolButton {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 28
                            text: root.compactActionText(modelData)
                            Accessible.name: root.compactActionLabel(modelData)
                            ToolTip.visible: hovered
                            ToolTip.text: root.compactActionLabel(modelData)
                            enabled: root.compactActionEnabled(modelData)
                            onClicked: root.compactAppAction(modelData)
                        }
                    }
                }
            }
            Text { visible: root.apps.length > 4; text: "+ " + (root.apps.length - 4) + " " + root.tr("more"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10 }
            Text { Layout.fillWidth: true; text: root.tr("detailsHint"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; wrapMode: Text.Wrap }
        }

        // Expanded details view: separate application/window and process-tree views.
        ColumnLayout {
            visible: root.expanded
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 7
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Button { Layout.fillWidth: true; text: root.tr("apps"); highlighted: root.activeTab === "apps"; onClicked: root.activeTab = "apps" }
                Button { Layout.fillWidth: true; text: root.tr("processes"); highlighted: root.activeTab === "processes"; onClicked: { root.activeTab = "processes"; root.refreshProcesses(); } }
            }
            ColumnLayout {
                visible: root.activeTab === "apps"
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 5
                Text { visible: !root.apps.length; Layout.fillWidth: true; text: root.tr("noApps"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
                ListView {
                    id: appList
                    visible: root.apps.length > 0
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 7
                    model: root.apps
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Rectangle {
                        id: appRow
                        required property var modelData
                        width: appList.width
                        height: appBody.implicitHeight + 16
                        radius: 9; color: Glass.tint(Session.surface, 0.68)
                        border.width: 1; border.color: Glass.tint(Session.accent, 0.15)
                        ColumnLayout {
                            id: appBody
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 8; spacing: 5
                            RowLayout {
                                Layout.fillWidth: true; spacing: 5
                                Text { Layout.fillWidth: true; text: appRow.modelData.name; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { text: appRow.modelData.windows.length + " " + root.tr("windows"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9 }
                            }
                            Repeater {
                                model: appRow.modelData.windows
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true; spacing: 5
                                    Text { Layout.fillWidth: true; text: root.windowTitle(modelData); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 10; elide: Text.ElideRight }
                                    Button { text: root.tr("closeWindow"); onClicked: root.closeWindow(modelData.address) }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 5
                                Text {
                                    Layout.fillWidth: true
                                    text: { const proc = root.processForApp(appRow.modelData); return proc ? root.tr("pid") + " " + proc.pid + " · " + root.processRoleLabel(proc) : root.tr("mappedWindow"); }
                                    color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9; wrapMode: Text.Wrap
                                }
                                Button {
                                    text: root.appActionLabel(appRow.modelData)
                                    enabled: !!root.processForApp(appRow.modelData) && root.processForApp(appRow.modelData).canSignal
                                        && !terminator.running && root.pendingProcessKey !== root.processKey(root.processForApp(appRow.modelData))
                                    visible: !!root.processForApp(appRow.modelData)
                                    onClicked: {
                                        const proc = root.processForApp(appRow.modelData);
                                        if (proc) root.requestSignal(proc, root.appForceReady(appRow.modelData));
                                    }
                                }
                            }
                        }
                    }
                }
                Text { Layout.fillWidth: true; text: root.tr("mappingHint"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9; wrapMode: Text.Wrap }
            }
            ColumnLayout {
                visible: root.activeTab === "processes"
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
                TextField {
                    Layout.fillWidth: true
                    placeholderText: root.tr("filterProcesses")
                    Accessible.name: root.tr("filterProcesses")
                    text: root.processQuery
                    onTextEdited: root.processQuery = text
                }
                Text { visible: !root.filteredProcesses.length; Layout.fillWidth: true; text: root.tr("noProcesses"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 11 }
                ListView {
                    id: processList
                    visible: root.filteredProcesses.length > 0
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
                    model: root.filteredProcesses
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Rectangle {
                        id: processRow
                        required property var modelData
                        x: processRow.modelData.appName ? Math.min(Number(processRow.modelData.depth || 0) * 10, 28) : 0
                        width: processList.width - x; height: processBody.implicitHeight + 14
                        radius: 8; color: Glass.tint(Session.surface, 0.68)
                        border.width: 1; border.color: Glass.tint(Session.accent, 0.12)
                        ColumnLayout {
                            id: processBody
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 7; spacing: 3
                            RowLayout {
                                Layout.fillWidth: true; spacing: 5
                                Text { Layout.fillWidth: true; text: (processRow.modelData.appName ? (Number(processRow.modelData.depth) > 0 ? "↳ " : "● ") : "• ") + processRow.modelData.name; color: Session.foreground; font.family: Session.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { text: root.tr("pid") + " " + processRow.modelData.pid; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9 }
                            }
                            Text { Layout.fillWidth: true; text: root.tr("ppid") + " " + (processRow.modelData.parentName || "PID") + " (" + processRow.modelData.ppid + ") · " + root.processRoleLabel(processRow.modelData); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9; wrapMode: Text.Wrap }
                            Text { Layout.fillWidth: true; text: processRow.modelData.command; color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9; elide: Text.ElideMiddle; maximumLineCount: 1 }
                            Text { Layout.fillWidth: true; text: root.associationLabel(processRow.modelData); color: processRow.modelData.appName ? Session.accent : Session.muted; font.family: Session.fontFamily; font.pixelSize: 9; wrapMode: Text.Wrap }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 5
                                Text { Layout.fillWidth: true; visible: !processRow.modelData.canSignal; text: root.tr("protected"); color: Session.muted; font.family: Session.fontFamily; font.pixelSize: 9; wrapMode: Text.Wrap }
                                Text { Layout.fillWidth: true; visible: processRow.modelData.canSignal && root.forceProcessKey !== root.processKey(processRow.modelData); text: "" }
                                Text { Layout.fillWidth: true; visible: root.forceProcessKey === root.processKey(processRow.modelData); text: root.tr("forceWarning"); color: "#e5b878"; font.family: Session.fontFamily; font.pixelSize: 9; wrapMode: Text.Wrap }
                                Button {
                                    visible: processRow.modelData.canSignal
                                    enabled: !terminator.running && root.pendingProcessKey !== root.processKey(processRow.modelData)
                                    text: root.forceProcessKey === root.processKey(processRow.modelData) ? root.tr("forceKill") : root.pendingProcessKey === root.processKey(processRow.modelData) ? "…" : root.tr("endProcess")
                                    onClicked: root.requestSignal(processRow.modelData, root.forceProcessKey === root.processKey(processRow.modelData))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
