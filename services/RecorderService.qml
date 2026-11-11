pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool isRecording: false
    property int durationSeconds: 0
    readonly property string durationFormatted: {
        const mins = Math.floor(durationSeconds / 60);
        const secs = durationSeconds % 60;
        return `${mins < 10 ? "0" + mins : mins}:${secs < 10 ? "0" + secs : secs}`;
    }

    function toggleRecordRegion() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/sora/scripts/record.sh"]);
        checkProc.running = true;
    }

    function toggleRecordFullscreen(sound) {
        const cmd = [Quickshell.env("HOME") + "/.config/quickshell/sora/scripts/record.sh", "-f"];
        if (sound) cmd.push("-s");
        Quickshell.execDetached(cmd);
        checkProc.running = true;
    }

    function stopRecording() {
        Quickshell.execDetached(["pkill", "--signal", "SIGINT", "-x", "wf-recorder"]);
        root.isRecording = false;
        root.durationSeconds = 0;
    }

    function takeScreenshotRegion() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/sora/scripts/screenshot.sh"]);
    }

    function takeScreenshotFullscreen() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/sora/scripts/screenshot.sh", "--fullscreen"]);
    }

    function takeScreenshotWindow() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/sora/scripts/screenshot.sh", "--window"]);
    }

    Process {
        id: checkProc
        command: ["pidof", "wf-recorder"]
        onExited: code => {
            const runningNow = (code === 0);
            if (runningNow) {
                if (!root.isRecording) {
                    root.isRecording = true;
                    root.durationSeconds = 0;
                }
            } else {
                root.isRecording = false;
                root.durationSeconds = 0;
            }
        }
    }

    property int _idleTick: 0

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (root.isRecording) {
                root.durationSeconds++;
                if (!checkProc.running) checkProc.running = true;
            } else {
                root._idleTick++;
                if (root._idleTick >= 5) {
                    root._idleTick = 0;
                    if (!checkProc.running) checkProc.running = true;
                }
            }
        }
    }
}
