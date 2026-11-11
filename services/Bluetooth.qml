pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    property bool powered: false
    property string connectedDevice: ""
    property var connectedMacs: ({})
    property var devices: []
    property string busyMac: ""
    property string busyAction: ""
    property bool powerBusy: false
    property bool scanning: false
    property string lastError: ""

    property string allDevsBuffer: ""
    property string connDevsBuffer: ""
    property string actionErrBuffer: ""

    function refresh(): void {
        if (!statusProc.running) statusProc.running = true;
        if (root.powered && !devProc.running) {
            connDevsBuffer = "";
            devProc.running = true;
        }
    }

    function loadDevices(): void {
        if (allDevsProc.running) return;
        allDevsBuffer = "";
        allDevsProc.running = true;
    }

    function clearError(): void {
        root.lastError = "";
    }

    function togglePower(): void {
        if (powerProc.running) return;
        const nextPower = !root.powered;
        root.powerBusy = true;
        root.lastError = "";
        if (!nextPower && scanProc.running) {
            root.scanning = false;
            scanProc.running = false;
        }
        powerProc.command = ["bluetoothctl", "power", nextPower ? "on" : "off"];
        powerProc.running = true;
    }

    function toggleScan(): void {
        if (!root.powered) return;
        if (scanProc.running) {
            root.scanning = false;
            scanProc.running = false;
            refresh();
            return;
        }
        root.lastError = "";
        root.scanning = true;
        scanProc.running = true;
    }

    function stopScan(): void {
        if (scanProc.running) {
            root.scanning = false;
            scanProc.running = false;
        }
    }

    function toggleDevice(mac: string, currentlyConnected: bool): void {
        if (!mac || actionProc.running) return;
        const dev = root.devices.find(d => d.mac === mac);
        const isPaired = dev ? !!dev.paired : true;
        root.busyMac = mac;
        root.lastError = "";
        root.actionErrBuffer = "";
        if (currentlyConnected) {
            root.busyAction = "disconnect";
            actionProc.command = ["bluetoothctl", "disconnect", mac];
        } else if (isPaired) {
            root.busyAction = "connect";
            actionProc.command = ["bluetoothctl", "connect", mac];
        } else {
            root.busyAction = "pair";
            actionProc.command = [
                "sh", "-c",
                "bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\" && bluetoothctl connect \"$1\"",
                "bt", mac
            ];
        }
        actionProc.running = true;
    }

    function forgetDevice(mac: string): void {
        if (!mac || actionProc.running) return;
        root.busyMac = mac;
        root.busyAction = "remove";
        root.lastError = "";
        root.actionErrBuffer = "";
        actionProc.command = ["bluetoothctl", "remove", mac];
        actionProc.running = true;
    }

    Component.onCompleted: {
        refresh();
        loadDevices();
    }

    Timer {
        id: bgPollTimer
        interval: (Config.dashboardOpen && Config.activeSubPanel === "bluetooth") ? 3000 : 15000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Config
        function onDashboardOpenChanged() {
            if (Config.dashboardOpen) root.refresh();
        }
        function onActiveSubPanelChanged() {
            if (Config.activeSubPanel === "bluetooth") {
                root.refresh();
                root.loadDevices();
            }
        }
    }

    Timer {
        id: scanPollTimer
        interval: 1400
        repeat: true
        running: root.scanning && root.powered
        onTriggered: root.loadDevices()
    }

    Process {
        id: statusProc
        command: ["bluetoothctl", "show"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("Powered: yes")) root.powered = true;
                else if (data.includes("Powered: no")) {
                    root.powered = false;
                    root.scanning = false;
                    root.connectedDevice = "";
                    root.connectedMacs = ({});
                }
            }
        }
    }

    Process {
        id: devProc
        command: ["bluetoothctl", "devices", "Connected"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.connDevsBuffer += data + "\n";
            }
        }
        onExited: {
            const lines = root.connDevsBuffer.trim().split("\n").filter(l => l.startsWith("Device "));
            const macMap = {};
            for (const line of lines) {
                const parts = line.split(" ");
                if (parts.length >= 2) macMap[parts[1]] = true;
            }
            root.connectedMacs = macMap;
            if (lines.length > 0) {
                const parts = lines[0].split(" ");
                root.connectedDevice = parts.slice(2).join(" ");
            } else {
                root.connectedDevice = "";
            }
            root.loadDevices();
        }
    }

    Process {
        id: allDevsProc
        command: [
            "sh", "-c",
            "for mac in $(bluetoothctl devices | awk '{print $2}'); do echo '===DEV===' \"$mac\"; bluetoothctl info \"$mac\"; done"
        ]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.allDevsBuffer += data + "\n";
            }
        }
        onExited: {
            const blocks = root.allDevsBuffer.split("===DEV=== ");
            const list = [];
            for (const block of blocks) {
                const trimmed = block.trim();
                if (!trimmed) continue;
                const lines = trimmed.split("\n");
                const mac = lines[0].trim();
                if (!mac || mac.length < 11) continue;

                let name = "";
                let alias = "";
                let iconType = "";
                let paired = false;
                let trusted = false;
                let infoConn = false;
                let battery = -1;

                for (let i = 1; i < lines.length; i++) {
                    const l = lines[i].trim();
                    if (l.startsWith("Name:")) name = l.slice(5).trim();
                    else if (l.startsWith("Alias:")) alias = l.slice(6).trim();
                    else if (l.startsWith("Icon:")) iconType = l.slice(5).trim();
                    else if (l.startsWith("Paired:")) paired = l.includes("yes");
                    else if (l.startsWith("Trusted:")) trusted = l.includes("yes");
                    else if (l.startsWith("Connected:")) infoConn = l.includes("yes");
                    else if (l.startsWith("Battery Percentage:")) {
                        const m = l.match(/\((\d+)\)/);
                        if (m) battery = parseInt(m[1], 10);
                    }
                }
                const resolvedName = (alias || name || mac).trim();
                const isConnected = !!root.connectedMacs[mac] || infoConn;
                list.push({
                    mac: mac,
                    name: resolvedName,
                    iconType: iconType,
                    paired: paired,
                    trusted: trusted,
                    connected: isConnected,
                    battery: battery
                });
            }
            list.sort((a, b) => {
                if (a.connected !== b.connected) return a.connected ? -1 : 1;
                if (a.paired !== b.paired) return a.paired ? -1 : 1;
                return a.name.localeCompare(b.name);
            });
            root.devices = list;
        }
    }

    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "7", "scan", "on"]
        running: false
        onExited: {
            root.scanning = false;
            root.refresh();
        }
    }

    Process {
        id: powerProc
        command: []
        running: false
        onExited: (exitCode, exitStatus) => {
            root.powerBusy = false;
            if (exitCode !== 0) {
                root.lastError = "Unable to switch Bluetooth adapter";
            }
            root.refresh();
        }
    }

    Process {
        id: actionProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: data => {
                const lower = data.toLowerCase();
                if (lower.includes("failed") || lower.includes("not available") || lower.includes("error")) {
                    root.actionErrBuffer += data.trim() + " ";
                }
            }
        }
        stderr: SplitParser {
            onRead: data => {
                root.actionErrBuffer += data.trim() + " ";
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.busyMac = "";
            root.busyAction = "";
            if (exitCode !== 0 || root.actionErrBuffer.trim().length > 0) {
                const msg = root.actionErrBuffer.trim();
                root.lastError = msg.length > 0
                    ? (msg.length > 92 ? msg.slice(0, 89) + "..." : msg)
                    : "Bluetooth operation failed";
            }
            root.actionErrBuffer = "";
            root.refresh();
        }
    }
}
