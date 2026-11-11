pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // "power-saver", "balanced", "performance"
    property string activeProfile: "balanced"
    property string _applyingProfile: ""
    property string _pendingProfile: ""

    function _runSetProfile(profileName: string): void {
        _applyingProfile = profileName;
        _pendingProfile = "";
        setProc.command = [
            "busctl", "--system", "set-property",
            "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles",
            "net.hadess.PowerProfiles", "ActiveProfile", "s", profileName
        ];
        setProc.running = true;
    }

    function loadProfile(): void {
        if (setProc.running || _pendingProfile.length > 0 || getProc.running) return;
        getProc.running = true;
    }

    function setProfile(profileName: string): void {
        if (!profileName || profileName.length === 0) return;
        if (!setProc.running && _pendingProfile.length === 0 && activeProfile === profileName) return;
        activeProfile = profileName;
        verifyTimer.stop();
        if (setProc.running) {
            _pendingProfile = profileName;
            return;
        }
        _runSetProfile(profileName);
    }

    function cycleProfile(): void {
        if (activeProfile === "power-saver") setProfile("balanced");
        else if (activeProfile === "balanced") setProfile("performance");
        else setProfile("power-saver");
    }

    Timer {
        id: verifyTimer
        interval: 250
        onTriggered: root.loadProfile()
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.loadProfile()
    }

    Component.onCompleted: loadProfile()

    Process {
        id: setProc
        running: false
        onExited: exitCode => {
            if (root._pendingProfile.length > 0 && root._pendingProfile !== root._applyingProfile) {
                root._runSetProfile(root._pendingProfile);
                return;
            }
            root._applyingProfile = "";
            root._pendingProfile = "";
            if (exitCode !== 0) {
                console.warn("PowerService: gagal menerapkan profil daya, exitCode:", exitCode);
                root.loadProfile();
            } else {
                verifyTimer.restart();
            }
        }
    }

    Process {
        id: getProc
        command: [
            "busctl", "--system", "get-property",
            "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles",
            "net.hadess.PowerProfiles", "ActiveProfile"
        ]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (setProc.running || root._pendingProfile.length > 0) return;
                const m = data.match(/"([^"]+)"/);
                if (m && m[1].length > 0) root.activeProfile = m[1];
            }
        }
    }
}
