pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real brightness: 0.7
    property string deviceName: ""
    property int pendingPercent: -1
    property int _lastSentPercent: -1
    property bool synced: false

    signal osdTriggered()

    function update(): void {
        if (!readProc.running) readProc.running = true;
    }

    function setBrightness(percent: real): void {
        const clamped = Math.max(1, Math.min(100, Math.round(percent)));
        root.brightness = clamped / 100.0;
        root.pendingPercent = clamped;
        root.osdTriggered();
        debounceTimer.restart();
    }

    function increase(): void {
        setBrightness((root.brightness * 100) + 5);
    }

    function decrease(): void {
        setBrightness((root.brightness * 100) - 5);
    }

    Component.onCompleted: update()

    Timer {
        id: debounceTimer
        interval: 40
        running: false
        onTriggered: {
            if (root.pendingPercent >= 1 && !setProc.running) {
                root._lastSentPercent = root.pendingPercent;
                setProc.command = ["brightnessctl", "set", `${root.pendingPercent}%`];
                setProc.running = true;
            }
        }
    }

    Process {
        id: readProc
        command: ["brightnessctl", "-m"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (debounceTimer.running || setProc.running || root.pendingPercent >= 0) return;
                const parts = data.trim().split(",");
                if (parts.length >= 4) {
                    root.deviceName = parts[0];
                    const pct = parseInt(parts[3].replace("%", ""), 10);
                    if (!isNaN(pct)) {
                        root.brightness = Math.max(0.01, Math.min(1.0, pct / 100.0));
                    }
                }
            }
        }
        onExited: root.synced = true
    }

    Process {
        id: setProc
        command: []
        running: false
        onExited: {
            if (root.pendingPercent >= 1 && root.pendingPercent !== root._lastSentPercent) {
                debounceTimer.restart();
            } else {
                root.pendingPercent = -1;
                readProc.running = true;
            }
        }
    }
}
