pragma Singleton
import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string lastError: ""
    property bool busy: queue.length > 0 || currentTask !== null
    property int queueLength: queue.length

    signal actionCompleted(string subcommand, string action, bool success, var result, string error)
    signal errorOccurred(string message)

    // Internal task queue
    property var queue: []
    property var currentTask: null

    function send(subcommand: string, args: var, callback: var): void {
        const cmdArgs = Array.isArray(args) ? args : (args !== undefined && args !== null && String(args).length > 0 ? [String(args)] : []);
        const task = {
            subcommand: subcommand,
            args: cmdArgs,
            callback: (typeof callback === "function") ? callback : null,
            timestamp: Date.now()
        };

        // Deduplication: if high-frequency control actions (brightness, status), drop redundant pending tasks
        if (subcommand === "control" && cmdArgs.length > 0) {
            const act = cmdArgs[0];
            if (act === "brightness" || act === "status" || act === "ui-scale") {
                queue = queue.filter(t => !(t.subcommand === "control" && t.args.length > 0 && t.args[0] === act));
            }
        }

        queue.push(task);
        if (!worker.running) {
            pump.restart();
        }
    }

    function exec(commandList: var): void {
        if (!commandList || !commandList.length) return;
        try {
            Quickshell.execDetached(commandList);
        } catch (e) {
            const msg = String(e);
            console.error("IpcClient.exec failed:", msg);
            root.lastError = msg;
            root.errorOccurred(msg);
        }
    }

    Timer {
        id: pump
        interval: 0
        onTriggered: {
            if (worker.running || !queue.length) return;
            root.currentTask = queue.shift();
            root.queueLength = queue.length;

            const fullCommand = [Session.controller, root.currentTask.subcommand].concat(root.currentTask.args);
            worker.command = fullCommand;
            worker.running = true;
        }
    }

    Process {
        id: worker
        stdout: StdioCollector {
            id: outCollector
        }
        stderr: StdioCollector {
            id: errCollector
        }
        onExited: exitCode => {
            const task = root.currentTask;
            const stdoutText = outCollector.text.trim();
            const stderrText = errCollector.text.trim().replace(/^poly-shell:\s*/, "");
            const success = exitCode === 0;

            let parsedResult = null;
            if (stdoutText.length > 0) {
                try {
                    parsedResult = JSON.parse(stdoutText);
                } catch (_) {
                    parsedResult = stdoutText;
                }
            }

            if (!success && stderrText.length > 0) {
                root.lastError = stderrText;
                root.errorOccurred(stderrText);
                console.error("IpcClient error [" + (task ? task.subcommand : "") + "]:", stderrText);
            }

            if (task && task.callback) {
                try {
                    task.callback(parsedResult, success ? "" : (stderrText || "Exit code " + exitCode));
                } catch (cbErr) {
                    console.error("IpcClient callback error:", String(cbErr));
                }
            }

            if (task) {
                const actionName = task.args.length > 0 ? task.args[0] : "";
                root.actionCompleted(task.subcommand, actionName, success, parsedResult, success ? "" : stderrText);
            }

            root.currentTask = null;
            if (queue.length > 0) {
                pump.restart();
            }
        }
    }
}

