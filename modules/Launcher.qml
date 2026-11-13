import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../config"
import "../components"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: Config.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property real openProgress: Config.launcherOpen ? 1.0 : 0.0
    Behavior on openProgress {
        NumberAnimation {
            duration: Config.launcherOpen ? 260 : 180
            easing.type: Config.launcherOpen ? Easing.OutQuint : Easing.InQuad
        }
    }

    color: "transparent"
    visible: openProgress > 0.005

    property int selectedIndex: 0
    property bool showAllApps: false
    property var recentIds: []
    readonly property string recentFilePath: `${Quickshell.env("HOME")}/.config/quickshell/sora/config/launcher_recent.json`

    FileView {
        id: recentFile
        path: root.recentFilePath
        preload: true
        blockLoading: false
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (Array.isArray(parsed)) {
                    root.recentIds = parsed.filter(id => typeof id === "string" && id.length > 0).slice(0, 8);
                }
            } catch (e) {}
        }
    }

    function recordRecent(appId: string): void {
        if (!appId || appId.length === 0) return;
        const next = [appId, ...recentIds.filter(id => id !== appId)].slice(0, 8);
        recentIds = next;
        recentFile.setText(JSON.stringify(next));
    }

    readonly property var allEntries: [...DesktopEntries.applications.values]
        .filter(a => a && a.name && !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))
    property var filteredEntries: []

    readonly property var pinnedApps: {
        const priorityKeywords = [
            "foot", "alacritty", "terminal", "firefox", "chrome", "brave", "browser",
            "antigravity", "code", "codium", "cursor", "discord", "steam", "heroic",
            "thunar", "nautilus", "dolphin", "files", "audacity", "gimp",
            "settings", "obs", "spotify", "vlc"
        ];
        const curated = [];
        const seen = new Set();
        for (let i = 0; i < priorityKeywords.length; i++) {
            const kw = priorityKeywords[i];
            for (let j = 0; j < allEntries.length; j++) {
                const app = allEntries[j];
                const n = (app.name ?? "").toLowerCase();
                const id = (app.id ?? "").toLowerCase();
                if ((n.includes(kw) || id.includes(kw)) && !seen.has(app.id)) {
                    curated.push(app);
                    seen.add(app.id);
                    break;
                }
            }
        }
        for (let k = 0; k < allEntries.length; k++) {
            if (curated.length >= 18) break;
            const app2 = allEntries[k];
            if (!seen.has(app2.id)) {
                curated.push(app2);
                seen.add(app2.id);
            }
        }
        return curated.slice(0, 18);
    }

    readonly property var recentApps: {
        const out = [];
        for (let i = 0; i < recentIds.length && out.length < 4; i++) {
            const match = allEntries.find(a => a.id === recentIds[i]);
            if (match) out.push(match);
        }
        return out;
    }

    function updateFilter(): void {
        const q = searchField.text.trim().toLowerCase();
        if (q.length === 0) {
            filteredEntries = allEntries.slice(0, 30);
        } else {
            filteredEntries = allEntries.filter(app => {
                const name = (app.name ?? "").toLowerCase();
                const generic = (app.genericName ?? "").toLowerCase();
                const comment = (app.comment ?? "").toLowerCase();
                const id = (app.id ?? "").toLowerCase();
                const kw = Array.isArray(app.keywords) ? app.keywords.join(" ").toLowerCase() : "";
                return name.includes(q) || generic.includes(q) || comment.includes(q) || id.includes(q) || kw.includes(q);
            }).slice(0, 30);
        }
        selectedIndex = 0;
    }

    function launchSelected(): void {
        const q = searchField.text.trim();
        if (filteredEntries.length > 0 && selectedIndex >= 0 && selectedIndex < filteredEntries.length) {
            const target = filteredEntries[selectedIndex];
            recordRecent(target.id ?? "");
            Config.launcherOpen = false;
            target.execute();
        } else if (q.length > 0) {
            Config.launcherOpen = false;
            const cmd = q.startsWith(":") ? q.slice(1).trim() : q;
            if (cmd.length > 0) Quickshell.execDetached(["sh", "-c", cmd]);
        }
    }

    function launchApp(app: var): void {
        if (!app) return;
        recordRecent(app.id ?? "");
        Config.launcherOpen = false;
        app.execute();
    }

    Connections {
        target: Config
        function onLauncherOpenChanged() {
            if (Config.launcherOpen) {
                searchField.text = "";
                root.showAllApps = false;
                root.updateFilter();
                searchField.forceActiveFocus();
            }
        }
    }

    Component.onCompleted: {
        updateFilter();
        if (Config.launcherOpen) searchField.forceActiveFocus();
    }

    // Smooth Dim Backdrop (In & Out fade)
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.alpha(Theme.background, (Theme.isDarkMode ? 0.38 : 0.16) * root.openProgress)
        opacity: root.openProgress

        MouseArea {
            anchors.fill: parent
            enabled: Config.launcherOpen
            onClicked: Config.launcherOpen = false
        }
    }

    RectangularShadow {
        anchors.fill: startMenuCard
        radius: startMenuCard.radius
        blur: Math.round(16 + 8 * root.openProgress)
        spread: 0.0
        offset.y: Math.round(4 + 4 * root.openProgress)
        color: Qt.alpha("#000000", (Theme.isDarkMode ? 0.44 : 0.12) * root.openProgress)
        opacity: root.openProgress
        scale: startMenuCard.scale
        z: startMenuCard.z - 1
    }

    Rectangle {
        id: startMenuCard
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -16 + Math.round((1.0 - root.openProgress) * (Config.launcherOpen ? 20 : 12))
        width: Math.min(656, Math.max(360, root.width - 32))
        height: Math.min(556, Math.max(340, root.height - 64))
        radius: 14
        color: Qt.alpha(Theme.background, Theme.isDarkMode ? 0.94 : 0.97)
        border.width: 1
        border.color: Theme.outlineStrong
        opacity: Math.pow(root.openProgress, 1.15)
        scale: 0.94 + (0.06 * root.openProgress)
        clip: true
        Keys.onEscapePressed: Config.launcherOpen = false

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // 1. Search Bar
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 62
                color: "transparent"

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    height: 40
                    radius: 10
                    color: Theme.surface
                    border.width: searchField.activeFocus ? 1.5 : 0
                    border.color: Theme.accentInk

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 10

                        MatIcon {
                            icon: "search"
                            size: 18
                            color: searchField.text ? Theme.accentInk : Theme.subtext
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Normal
                            selectByMouse: true
                            clip: true

                            Text {
                                anchors.fill: parent
                                text: "Cari aplikasi atau jalankan perintah..."
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.subtext
                                visible: !searchField.text
                            }

                            onTextChanged: root.updateFilter()

                            Keys.onEscapePressed: Config.launcherOpen = false
                            Keys.onReturnPressed: root.launchSelected()

                            Keys.onDownPressed: {
                                if (root.filteredEntries.length > 0) {
                                    root.selectedIndex = Math.min(root.filteredEntries.length - 1, root.selectedIndex + 1);
                                    if (resultsList.visible) resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                }
                            }

                            Keys.onUpPressed: {
                                if (root.filteredEntries.length > 0) {
                                    root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                                    if (resultsList.visible) resultsList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                }
                            }
                        }

                        Rectangle {
                            visible: searchField.text.length > 0
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 6
                            color: clearSearchM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                            activeFocusOnTab: searchField.text.length > 0 && Config.launcherOpen
                            Accessible.role: Accessible.Button
                            Accessible.name: "Bersihkan pencarian"

                            MatIcon {
                                anchors.centerIn: parent
                                icon: "close"
                                size: 14
                                color: Theme.text
                            }

                            MouseArea {
                                id: clearSearchM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchField.text = "";
                                    root.updateFilter();
                                    searchField.forceActiveFocus();
                                }
                            }

                            Keys.onReturnPressed: {
                                searchField.text = "";
                                root.updateFilter();
                                searchField.forceActiveFocus();
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.outline
                }
            }

            // 2. Body
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Search Results
                ListView {
                    id: resultsList
                    anchors.fill: parent
                    anchors.margins: 14
                    clip: true
                    spacing: 4
                    visible: searchField.text.trim().length > 0 && root.filteredEntries.length > 0
                    model: root.filteredEntries

                    delegate: Rectangle {
                        id: searchRow
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: index === root.selectedIndex

                        width: resultsList.width
                        implicitHeight: 46
                        radius: 9
                        color: isSelected
                            ? Theme.surfaceContainerHigh
                            : (rowMouse.containsMouse ? Theme.surfaceContainer : "transparent")
                        border.width: isSelected ? 1 : 0
                        border.color: Theme.accent

                        Behavior on color { ColorAnimation { duration: 90 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            IconImage {
                                implicitWidth: 26
                                implicitHeight: 26
                                asynchronous: true
                                source: Config.resolveIcon(searchRow.modelData?.icon, "application-x-executable")
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: searchRow.modelData.name ?? ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: searchRow.isSelected ? Font.DemiBold : Font.Normal
                                    color: Theme.text
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: searchRow.modelData.comment || searchRow.modelData.genericName || "Aplikasi"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Theme.subtext
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                visible: searchRow.isSelected
                                implicitWidth: 54
                                implicitHeight: 22
                                radius: 6
                                color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "Buka ↵"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Theme.accentOnFill
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedIndex = searchRow.index;
                                root.launchSelected();
                            }
                        }
                    }
                }

                // Empty State: Direct Shell Command Action
                Item {
                    id: cmdEmptyWrap
                    anchors.fill: parent
                    anchors.margins: 18
                    visible: searchField.text.trim().length > 0 && root.filteredEntries.length === 0

                    readonly property string rawQuery: searchField.text.trim()
                    readonly property string shellCmd: rawQuery.startsWith(":") ? rawQuery.slice(1).trim() : rawQuery

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 54
                        radius: 10
                        color: cmdFallbackM.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                        border.width: 1
                        border.color: Theme.accent

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12

                            MatIcon {
                                icon: "terminal"
                                size: 20
                                color: Theme.accentInk
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: "Jalankan perintah shell"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }

                                Text {
                                    text: cmdEmptyWrap.shellCmd
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                    color: Theme.subtext
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                implicitWidth: 74
                                implicitHeight: 24
                                radius: 6
                                color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "Jalankan ↵"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Theme.accentOnFill
                                }
                            }
                        }

                        MouseArea {
                            id: cmdFallbackM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchSelected()
                        }
                    }
                }

                // All Applications Alphabetical
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    clip: true
                    visible: searchField.text.trim().length === 0 && root.showAllApps

                    RowLayout {
                        Layout.fillWidth: true

                        Rectangle {
                            implicitWidth: backBtn.implicitWidth + 14
                            implicitHeight: 28
                            radius: 7
                            color: backHover.containsMouse ? Theme.surfaceContainer : Theme.surface
                            activeFocusOnTab: root.showAllApps && Config.launcherOpen
                            Accessible.role: Accessible.Button
                            Accessible.name: "Kembali ke daftar utama"

                            RowLayout {
                                id: backBtn
                                anchors.centerIn: parent
                                spacing: 4

                                MatIcon {
                                    icon: "arrow_back"
                                    size: 14
                                    color: Theme.subtext
                                }

                                Text {
                                    text: "Kembali"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: Theme.text
                                }
                            }

                            MouseArea {
                                id: backHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showAllApps = false
                            }

                            Keys.onReturnPressed: root.showAllApps = false
                            Keys.onSpacePressed: root.showAllApps = false
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Semua Aplikasi"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.subtext
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: root.allEntries

                        delegate: Rectangle {
                            id: allRow
                            required property var modelData
                            width: ListView.view ? ListView.view.width : 624
                            implicitHeight: 38
                            radius: 7
                            color: allM.containsMouse ? Theme.surfaceContainer : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                IconImage {
                                    implicitWidth: 22
                                    implicitHeight: 22
                                    asynchronous: true
                                    source: Config.resolveIcon(allRow.modelData?.icon, "application-x-executable")
                                }

                                Text {
                                    text: allRow.modelData.name ?? ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: Theme.text
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: allM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.launchApp(allRow.modelData)
                            }
                        }
                    }
                }

                // Default Grid View
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    clip: true
                    visible: searchField.text.trim().length === 0 && !root.showAllApps

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Aplikasi Utama"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: allLabel.implicitWidth + 14
                            implicitHeight: 28
                            radius: 7
                            color: allBtnM.containsMouse ? Theme.surfaceContainer : Theme.surface
                            activeFocusOnTab: !root.showAllApps && searchField.text.trim().length === 0 && Config.launcherOpen
                            Accessible.role: Accessible.Button
                            Accessible.name: "Lihat semua aplikasi"

                            RowLayout {
                                id: allLabel
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    text: "Semua aplikasi"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: Theme.text
                                }

                                MatIcon {
                                    icon: "chevron_right"
                                    size: 14
                                    color: Theme.subtext
                                }
                            }

                            MouseArea {
                                id: allBtnM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showAllApps = true
                            }

                            Keys.onReturnPressed: root.showAllApps = true
                            Keys.onSpacePressed: root.showAllApps = true
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 6
                        rowSpacing: 4
                        columnSpacing: 4

                        Repeater {
                            model: root.pinnedApps

                            Rectangle {
                                id: pinTile
                                required property var modelData

                                Layout.fillWidth: true
                                implicitHeight: 68
                                radius: 9
                                color: pinM.containsMouse ? Theme.surfaceContainer : "transparent"

                                Behavior on color { ColorAnimation { duration: 90 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    IconImage {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        asynchronous: true
                                        source: Config.resolveIcon(pinTile.modelData?.icon, "application-x-executable")
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.maximumWidth: 92
                                        text: pinTile.modelData.name ?? ""
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Normal
                                        color: Theme.text
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: pinM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.launchApp(pinTile.modelData)
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        visible: root.recentApps.length > 0

                        Text {
                            text: "Terakhir Dibuka"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        visible: root.recentApps.length > 0
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 10

                        Repeater {
                            model: root.recentApps

                            Rectangle {
                                id: recTile
                                required property var modelData

                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: 9
                                color: recM.containsMouse ? Theme.surfaceContainer : Theme.surface
                                activeFocusOnTab: !root.showAllApps && searchField.text.trim().length === 0 && Config.launcherOpen
                                Accessible.role: Accessible.Button
                                Accessible.name: recTile.modelData.name ?? "Aplikasi"

                                Behavior on color { ColorAnimation { duration: 90 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    IconImage {
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        asynchronous: true
                                        source: Config.resolveIcon(recTile.modelData?.icon, "application-x-executable")
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: recTile.modelData.name ?? ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: Theme.text
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: recTile.modelData.comment || recTile.modelData.genericName || "Aplikasi"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.subtext
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: recM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.launchApp(recTile.modelData)
                                }

                                Keys.onReturnPressed: root.launchApp(recTile.modelData)
                                Keys.onSpacePressed: root.launchApp(recTile.modelData)
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // 3. Footer
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                color: Theme.surfaceContainerLow

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Theme.outline
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 10

                    Item {
                        implicitWidth: 32
                        implicitHeight: 32

                        Rectangle {
                            id: launcherAvaMask
                            anchors.fill: parent
                            radius: 16
                            color: "#ffffff"
                            visible: false
                            layer.enabled: true
                        }

                        Item {
                            anchors.fill: parent
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: launcherAvaMask
                                maskSpreadAtMin: 1.0
                                maskThresholdMin: 0.5
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: (Quickshell.env("USER") || "K").slice(0, 1).toUpperCase()
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: Theme.accentOnFill
                                }
                            }

                            Image {
                                anchors.fill: parent
                                source: `file://${Quickshell.env("HOME")}/.face`
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 0

                        Text {
                            text: Quickshell.env("USER") || "user"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            text: "SORA · " + (Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland")
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.subtext
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 8
                        color: setM.containsMouse ? Theme.surfaceContainer : "transparent"
                        activeFocusOnTab: Config.launcherOpen
                        Accessible.role: Accessible.Button
                        Accessible.name: "Buka Dashboard Pengaturan"

                        MatIcon {
                            anchors.centerIn: parent
                            icon: "settings"
                            size: 17
                            color: setM.containsMouse ? Theme.text : Theme.subtext
                        }

                        MouseArea {
                            id: setM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.launcherOpen = false;
                                Config.toggleDashboard();
                            }
                        }

                        Keys.onReturnPressed: { Config.launcherOpen = false; Config.toggleDashboard(); }
                        Keys.onSpacePressed: { Config.launcherOpen = false; Config.toggleDashboard(); }
                    }

                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 8
                        color: pwrM.pressed
                            ? Theme.urgent
                            : (pwrM.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                        border.width: (pwrM.containsMouse && !pwrM.pressed) ? 1 : 0
                        border.color: Theme.urgentInk
                        activeFocusOnTab: Config.launcherOpen
                        Accessible.role: Accessible.Button
                        Accessible.name: "Buka Menu Daya"

                        MatIcon {
                            anchors.centerIn: parent
                            icon: "power_settings_new"
                            size: 17
                            color: pwrM.pressed
                                ? (Theme.isDarkMode ? "#171A1C" : "#F8FAFA")
                                : (pwrM.containsMouse ? Theme.urgentInk : Theme.subtext)
                        }

                        MouseArea {
                            id: pwrM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.launcherOpen = false;
                                Config.togglePowerMenu();
                            }
                        }

                        Keys.onReturnPressed: { Config.launcherOpen = false; Config.togglePowerMenu(); }
                        Keys.onSpacePressed: { Config.launcherOpen = false; Config.togglePowerMenu(); }
                    }
                }
            }
        }
    }
}
