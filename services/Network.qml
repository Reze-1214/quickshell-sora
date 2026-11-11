pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isConnected: false
    property bool wifiEnabled: true
    property string ssid: ""
    readonly property string activeSsid: ssid
    property string networkType: ""
    property string status: "disconnected"
    property string activeWifiIface: ""
    property var accessPoints: []
    property var savedSsids: ({})
    property string activeBand: ""
    property string activeSecurity: ""
    property string activeRate: ""
    property int activeSignal: 0
    property bool scanning: false
    property bool actionBusy: false
    property string connectingSsid: ""
    property string lastError: ""

    signal passwordRequired(string ssid)

    property string rawBuffer: ""
    property string savedBuffer: ""
    property string cacheScanBuffer: ""
    property string scanBuffer: ""
    property string connectErrBuffer: ""
    property string connectOutBuffer: ""
    property string actionErrBuffer: ""

    function isSavedSsid(targetSsid: string): bool {
        return !!root.savedSsids[targetSsid];
    }

    function applyScanOutput(raw: string): void {
        if (!root.wifiEnabled) {
            root.accessPoints = [];
            root.activeBand = "";
            root.activeSecurity = "";
            root.activeRate = "";
            root.activeSignal = 0;
            return;
        }
        const lines = raw.trim().split("\n");
        const bestBySsid = {};
        for (const line of lines) {
            if (!line.trim()) continue;
            const parts = line.split(":");
            if (parts.length >= 6) {
                const inUse = parts[0].trim() === "*";
                const sig = parseInt(parts[1], 10) || 0;
                const chan = parseInt(parts[2], 10) || 0;
                const rawSec = parts[3].trim();
                const secClean = (rawSec === "--" || rawSec.length === 0) ? "" : rawSec;
                const rawRate = parts[4].trim();
                const rateClean = (rawRate === "--" || rawRate.length === 0) ? "" : rawRate;
                const netSsid = parts.slice(5).join(":").replace(/\\:/g, ":").trim();
                if (netSsid.length === 0) continue;
                const band = chan > 14 ? "5 GHz" : (chan > 0 ? "2.4 GHz" : "");
                const saved = !!root.savedSsids[netSsid];
                const candidate = {
                    active: inUse,
                    ssid: netSsid,
                    signal: sig,
                    secured: secClean.length > 0,
                    security: secClean.length > 0 ? secClean : "Open",
                    band: band,
                    rate: rateClean,
                    saved: saved
                };
                const existing = bestBySsid[netSsid];
                if (!existing || (candidate.active && !existing.active) || (!existing.active && candidate.signal > existing.signal)) {
                    bestBySsid[netSsid] = candidate;
                }
            }
        }
        const list = Object.values(bestBySsid);
        list.sort((a, b) => {
            if (a.active !== b.active) return a.active ? -1 : 1;
            if (a.saved !== b.saved) return a.saved ? -1 : 1;
            return b.signal - a.signal;
        });

        const activeAp = list.find(ap => ap.active || (root.isConnected && ap.ssid === root.ssid));
        if (activeAp) {
            root.activeBand = activeAp.band;
            root.activeSecurity = activeAp.security;
            root.activeRate = activeAp.rate;
            root.activeSignal = activeAp.signal;
        } else {
            root.activeBand = "";
            root.activeSecurity = "";
            root.activeRate = "";
            root.activeSignal = 0;
        }
        root.accessPoints = list.slice(0, 16);
    }

    function refresh(): void {
        rawBuffer = "";
        statusProc.running = true;
        refreshSaved();
    }

    function refreshSaved(): void {
        if (savedProc.running) return;
        savedBuffer = "";
        savedProc.running = true;
    }

    function clearError(): void {
        root.lastError = "";
    }

    function toggleWifi(): void {
        if (radioProc.running) return;
        const turnOn = !root.wifiEnabled;
        root.lastError = "";
        root.connectingSsid = "";
        radioProc.turnOnTarget = turnOn;
        radioProc.command = ["nmcli", "radio", "wifi", turnOn ? "on" : "off"];
        radioProc.running = true;
    }

    function scanWifi(): void {
        if (!root.wifiEnabled) return;
        refreshSaved();
        if (root.accessPoints.length === 0 && !cacheScanProc.running) {
            root.cacheScanBuffer = "";
            cacheScanProc.running = true;
        }
        if (scanProc.running) return;
        root.scanning = true;
        root.scanBuffer = "";
        scanProc.running = true;
    }

    function connectWifi(targetSsid: string, password: string): void {
        if (!targetSsid || connectProc.running || actionProc.running) return;
        root.connectingSsid = targetSsid;
        root.lastError = "";
        root.connectErrBuffer = "";
        root.connectOutBuffer = "";
        if (password && password.trim().length > 0) {
            connectProc.command = ["nmcli", "dev", "wifi", "connect", targetSsid, "password", password.trim()];
        } else if (root.savedSsids[targetSsid]) {
            connectProc.command = ["nmcli", "con", "up", "id", targetSsid];
        } else {
            connectProc.command = ["nmcli", "dev", "wifi", "connect", targetSsid];
        }
        connectProc.running = true;
    }

    function disconnectWifi(): void {
        if (actionProc.running || connectProc.running) return;
        const iface = root.activeWifiIface;
        const curSsid = root.ssid;
        if (!iface && !curSsid) return;
        root.actionBusy = true;
        root.lastError = "";
        root.actionErrBuffer = "";
        actionProc.actionKind = "disconnect";
        actionProc.targetSsid = curSsid;
        actionProc.command = iface
            ? ["nmcli", "dev", "disconnect", iface]
            : ["nmcli", "con", "down", "id", curSsid];
        actionProc.running = true;
    }

    function forgetWifi(targetSsid: string): void {
        if (!targetSsid || actionProc.running || connectProc.running) return;
        root.actionBusy = true;
        root.lastError = "";
        root.actionErrBuffer = "";
        actionProc.actionKind = "forget";
        actionProc.targetSsid = targetSsid;
        actionProc.command = ["nmcli", "con", "delete", "id", targetSsid];
        actionProc.running = true;
    }

    Component.onCompleted: refresh()

    // Event-driven stream via nmcli monitor (zero polling)
    Process {
        id: monitorProc
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: data => root.refresh()
        }
    }

    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "con", "show"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.savedBuffer += data + "\n";
            }
        }
        onExited: {
            const map = {};
            const lines = root.savedBuffer.trim().split("\n");
            for (const line of lines) {
                if (!line.trim()) continue;
                const idx = line.lastIndexOf(":");
                if (idx <= 0) continue;
                const name = line.slice(0, idx).replace(/\\:/g, ":").trim();
                const type = line.slice(idx + 1).trim();
                if (type === "802-11-wireless" && name.length > 0) {
                    map[name] = true;
                }
            }
            root.savedSsids = map;
            if (root.accessPoints.length > 0) {
                root.accessPoints = root.accessPoints.map(ap => {
                    const updated = Object.assign({}, ap);
                    updated.saved = !!map[ap.ssid];
                    return updated;
                });
            }
            root.savedBuffer = "";
        }
    }

    Process {
        id: statusProc
        command: ["sh", "-c", "nmcli -t -f WIFI g; echo '---DEV---'; nmcli -t -f TYPE,STATE,DEVICE,CONNECTION dev"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.rawBuffer += data + "\n";
            }
        }
        onExited: {
            const chunks = root.rawBuffer.split("---DEV---\n");
            if (chunks.length >= 2) {
                const wifiState = chunks[0].trim().toLowerCase();
                if (wifiState === "enabled" || wifiState === "disabled") {
                    root.wifiEnabled = (wifiState === "enabled");
                }
            }
            const devBlock = chunks.length >= 2 ? chunks[1] : root.rawBuffer;
            const lines = devBlock.trim().split("\n");
            let found = false;
            let detectedWifiIface = "";
            for (const line of lines) {
                const parts = line.split(":");
                if (parts.length >= 3 && parts[0] === "wifi" && parts[2].trim().length > 0) {
                    detectedWifiIface = parts[2].trim();
                }
                if (parts.length >= 4 && parts[1] === "connected" && parts[0] !== "loopback" && parts[0] !== "bridge") {
                    root.networkType = parts[0];
                    root.status = "connected";
                    root.ssid = parts.slice(3).join(":").replace(/\\:/g, ":");
                    root.isConnected = true;
                    if (parts[0] === "wifi") root.activeWifiIface = parts[2].trim();
                    found = true;
                    break;
                }
            }
            if (detectedWifiIface.length > 0 && root.activeWifiIface.length === 0) {
                root.activeWifiIface = detectedWifiIface;
            }
            if (!found) {
                root.isConnected = false;
                root.status = "disconnected";
                root.ssid = "";
                root.activeBand = "";
                root.activeSecurity = "";
                root.activeRate = "";
                root.activeSignal = 0;
            }
            if (!root.wifiEnabled) {
                root.accessPoints = [];
            }
            root.rawBuffer = "";
        }
    }

    Timer {
        id: postRadioScanTimer
        interval: 750
        repeat: false
        onTriggered: {
            if (root.wifiEnabled) root.scanWifi();
        }
    }

    Process {
        id: radioProc
        property bool turnOnTarget: false
        command: []
        running: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.wifiEnabled = radioProc.turnOnTarget;
                if (radioProc.turnOnTarget) postRadioScanTimer.restart();
                else root.accessPoints = [];
            } else {
                root.lastError = "Unable to switch Wi-Fi radio";
            }
            root.refresh();
        }
    }

    Process {
        id: cacheScanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,CHAN,SECURITY,RATE,SSID", "dev", "wifi", "list", "--rescan", "no"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.cacheScanBuffer += data + "\n";
            }
        }
        onExited: {
            if (root.accessPoints.length === 0) {
                root.applyScanOutput(root.cacheScanBuffer);
            }
            root.cacheScanBuffer = "";
        }
    }

    Process {
        id: scanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,CHAN,SECURITY,RATE,SSID", "dev", "wifi", "list"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.scanBuffer += data + "\n";
            }
        }
        onExited: {
            root.scanning = false;
            root.applyScanOutput(root.scanBuffer);
            root.scanBuffer = "";
        }
    }

    Process {
        id: connectProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.connectOutBuffer += data + " ";
            }
        }
        stderr: SplitParser {
            onRead: data => {
                root.connectErrBuffer += data + " ";
            }
        }
        onExited: (exitCode, exitStatus) => {
            const target = root.connectingSsid;
            root.connectingSsid = "";
            if (exitCode !== 0) {
                const rawMsg = (root.connectErrBuffer.trim() || root.connectOutBuffer.trim())
                    .replace(/^(Error|Galat):\s*/i, "")
                    .trim();
                const lowerMsg = rawMsg.toLowerCase();
                root.lastError = rawMsg.length > 0
                    ? (rawMsg.length > 96 ? rawMsg.slice(0, 93) + "..." : rawMsg)
                    : `Failed to connect to ${target}`;
                if (lowerMsg.includes("secret") || lowerMsg.includes("password") || lowerMsg.includes("psk")) {
                    root.passwordRequired(target);
                }
            } else {
                root.lastError = "";
                root.scanWifi();
            }
            root.connectErrBuffer = "";
            root.connectOutBuffer = "";
            root.refresh();
        }
    }

    Process {
        id: actionProc
        property string actionKind: ""
        property string targetSsid: ""
        command: []
        running: false
        stderr: SplitParser {
            onRead: data => {
                root.actionErrBuffer += data + " ";
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.actionBusy = false;
            if (exitCode !== 0) {
                const rawMsg = root.actionErrBuffer.trim().replace(/^(Error|Galat):\s*/i, "").trim();
                root.lastError = rawMsg.length > 0
                    ? rawMsg
                    : (actionProc.actionKind === "forget"
                        ? `Could not forget ${actionProc.targetSsid}`
                        : "Unable to disconnect Wi-Fi");
            }
            root.actionErrBuffer = "";
            root.refresh();
            if (root.wifiEnabled) root.scanWifi();
        }
    }
}
