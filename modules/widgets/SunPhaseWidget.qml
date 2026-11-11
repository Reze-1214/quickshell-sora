import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

// Agenda Kalender & Notifikasi (Pattern 1: Left Hero Accent Date Slab + Right Stacked Tray)
Item {
    id: root

    width: 280
    height: 100

    property var eventsMap: ({})
    property var markedDates: []
    property int eventsVersion: 0
    property bool eventsReady: false
    property bool marksReady: false
    property bool eventsError: false
    property bool marksError: false

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    readonly property string todayKey: Qt.formatDateTime(sysClock.date, "yyyy-MM-dd")

    readonly property var agendaSummary: {
        root.eventsVersion;
        const today = root.todayKey;
        const map = root.eventsMap ?? {};
        const marks = root.markedDates ?? [];
        const keysSet = new Set();

        for (const k in map) {
            if (/^\d{4}-\d{2}-\d{2}$/.test(k) && String(map[k] ?? "").trim().length > 0) {
                keysSet.add(k);
            }
        }
        for (const m of marks) {
            if (/^\d{4}-\d{2}-\d{2}$/.test(m)) {
                keysSet.add(m);
            }
        }

        const sorted = Array.from(keysSet).sort();
        const upcoming = sorted.filter(k => k >= today);
        const hasToday = keysSet.has(today);
        const todayNote = String(map[today] ?? "").trim();
        const nextKey = sorted.find(k => k > today) ?? "";
        const nextNote = nextKey.length > 0 ? String(map[nextKey] ?? "").trim() : "";

        return {
            hasToday: hasToday,
            todayNote: hasToday ? (todayNote.length > 0 ? todayNote : "Tanggal ditandai") : "",
            nextKey: nextKey,
            nextNote: nextKey.length > 0 ? (nextNote.length > 0 ? nextNote : "Tanggal ditandai") : "",
            upcomingCount: upcoming.length
        };
    }

    function formatShortKey(dateKey: string): string {
        const p = dateKey.split("-");
        if (p.length !== 3) return dateKey;
        const dt = new Date(parseInt(p[0], 10), parseInt(p[1], 10) - 1, parseInt(p[2], 10));
        return Qt.formatDateTime(dt, "d MMM");
    }

    FileView {
        id: eventsWatcher
        printErrors: false
        path: `${Quickshell.env("HOME")}/.config/quickshell/sora/config/calendar_events.json`
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: {
            root.eventsReady = true;
        }
        onLoaded: {
            root.eventsReady = true;
            const raw = text().trim();
            if (raw.length === 0) {
                root.eventsMap = ({});
                root.eventsError = false;
                root.eventsVersion++;
                return;
            }
            try {
                const obj = JSON.parse(raw);
                if (obj && typeof obj === "object" && !Array.isArray(obj)) {
                    root.eventsMap = obj;
                    root.eventsError = false;
                } else {
                    root.eventsError = true;
                }
            } catch (e) {
                root.eventsError = true;
            }
            root.eventsVersion++;
        }
    }

    FileView {
        id: marksWatcher
        printErrors: false
        path: `${Quickshell.env("HOME")}/.config/quickshell/sora/config/calendar_marks.json`
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: {
            root.marksReady = true;
        }
        onLoaded: {
            root.marksReady = true;
            const raw = text().trim();
            if (raw.length === 0) {
                root.markedDates = [];
                root.marksError = false;
                root.eventsVersion++;
                return;
            }
            try {
                const arr = JSON.parse(raw);
                if (Array.isArray(arr)) {
                    root.markedDates = arr;
                    root.marksError = false;
                } else {
                    root.marksError = true;
                }
            } catch (e) {
                root.marksError = true;
            }
            root.eventsVersion++;
        }
    }

    WidgetChassis {
        id: tray
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            spacing: 5

            // Left Hero Date Slab (Solid Accent Block)
            Rectangle {
                id: dateSlab
                Layout.preferredWidth: 80
                Layout.fillWidth: false
                Layout.fillHeight: true
                radius: tray.innerRadius
                color: tray.colAccent
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Buka Kalender"

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: tray.colAccentText === "#14171A"
                        ? Qt.rgba(0, 0, 0, dateMa.pressed ? 0.14 : (dateMa.containsMouse ? 0.07 : 0))
                        : Qt.rgba(1, 1, 1, dateMa.pressed ? 0.16 : (dateMa.containsMouse ? 0.09 : 0))
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    visible: dateSlab.activeFocus
                    border.width: 1.5
                    border.color: tray.colInk
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 0

                    Text {
                        text: Qt.formatDateTime(sysClock.date, "ddd · MMM")
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.features: Theme.tabularFeatures
                        color: tray.colAccentTextMuted
                    }

                    Text {
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        text: Qt.formatDateTime(sysClock.date, "dd")
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        font.features: Theme.tabularFeatures
                        color: tray.colAccentText
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        spacing: 4

                        MatIcon {
                            icon: "calendar_month"
                            size: 11
                            color: tray.colAccentTextMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.agendaSummary.upcomingCount > 0
                                ? `${root.agendaSummary.upcomingCount} agenda`
                                : "Kalender"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.features: Theme.tabularFeatures
                            color: tray.colAccentText
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: dateMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.toggleProfilePopover()
                }

                Keys.onReturnPressed: event => { Config.toggleProfilePopover(); event.accepted = true; }
                Keys.onSpacePressed: event => { Config.toggleProfilePopover(); event.accepted = true; }
            }

            // Right Companion Stack: Agenda Card + Notif/DND Split Row
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                // Top Matte Agenda Tray
                Rectangle {
                    id: agendaTile
                    readonly property bool isLoading: !root.eventsReady && !root.marksReady
                    readonly property bool hasError: root.eventsError || root.marksError
                    readonly property bool hasToday: !isLoading && !hasError && root.agendaSummary.hasToday
                    readonly property bool hasNext: !isLoading && !hasError && !hasToday && root.agendaSummary.nextKey.length > 0

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 40
                    Layout.preferredHeight: 56
                    clip: true
                    radius: tray.innerRadius
                    color: agendaMa.pressed ? tray.colTrayPress : (agendaMa.containsMouse ? tray.colTrayHover : tray.colTray)
                    border.width: 1
                    border.color: agendaTile.activeFocus ? tray.colAccentOnTray : tray.colTrayBorder
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Ringkasan Agenda Kalender"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 8
                        spacing: 6

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            Layout.alignment: Qt.AlignVCenter
                            Layout.minimumWidth: 0
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    if (agendaTile.hasError) return "Format kalender gagal dibaca";
                                    if (agendaTile.hasToday) {
                                        return root.agendaSummary.nextKey.length > 0
                                            ? `Hari ini · lanjut ${root.formatShortKey(root.agendaSummary.nextKey)}`
                                            : "Agenda hari ini";
                                    }
                                    if (agendaTile.hasNext) {
                                        return `Berikutnya · ${root.formatShortKey(root.agendaSummary.nextKey)}`;
                                    }
                                    return "Agenda";
                                }
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                font.features: Theme.tabularFeatures
                                color: agendaTile.hasError
                                    ? tray.colUrgentInk
                                    : (agendaTile.hasToday ? tray.colAccentOnTray : tray.colMuted)
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    if (agendaTile.isLoading) return "Memuat agenda...";
                                    if (agendaTile.hasError) {
                                        return (root.eventsError && root.marksError)
                                            ? "Periksa file kalender di config/"
                                            : (root.marksError ? "Periksa config/calendar_marks.json" : "Periksa config/calendar_events.json");
                                    }
                                    if (agendaTile.hasToday) return root.agendaSummary.todayNote;
                                    if (agendaTile.hasNext) return root.agendaSummary.nextNote;
                                    return "Belum ada agenda, klik untuk tambah";
                                }
                                font.family: Theme.fontFamily
                                font.pixelSize: (agendaTile.hasToday || agendaTile.hasNext) ? 12 : 10
                                font.weight: (agendaTile.hasToday || agendaTile.hasNext) ? Font.DemiBold : Font.Medium
                                color: (agendaTile.hasToday || agendaTile.hasNext) ? tray.colInk : tray.colMuted
                                elide: Text.ElideRight
                            }
                        }

                        MatIcon {
                            icon: "chevron_right"
                            size: 14
                            color: agendaMa.containsMouse ? tray.colInk : tray.colMuted
                        }
                    }

                    MouseArea {
                        id: agendaMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.toggleProfilePopover()
                    }

                    Keys.onReturnPressed: event => { Config.toggleProfilePopover(); event.accepted = true; }
                    Keys.onSpacePressed: event => { Config.toggleProfilePopover(); event.accepted = true; }
                }

                // Bottom Row: Notifications | DND Toggle
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 28
                    spacing: 4

                    Rectangle {
                        id: notifTile
                        readonly property int count: Config.notifHistory.length
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: tray.innerRadius
                        color: notifMa.pressed ? tray.colTrayPress : (notifMa.containsMouse ? tray.colTrayHover : tray.colTray)
                        border.width: 1
                        border.color: notifTile.activeFocus ? tray.colAccentOnTray : tray.colTrayBorder
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Buka Riwayat Notifikasi"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 6
                            spacing: 5

                            MatIcon {
                                icon: notifTile.count > 0 ? "notifications_unread" : "notifications"
                                size: 12
                                fill: notifTile.count > 0 ? 1.0 : 0.0
                                color: notifTile.count > 0 ? tray.colAccentOnTray : tray.colMuted
                            }

                            Text {
                                Layout.fillWidth: true
                                text: notifTile.count > 0
                                    ? `${notifTile.count} · ${Config.notifHistory[0].summary}`
                                    : "Tanpa notifikasi"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: notifTile.count > 0 ? Font.DemiBold : Font.Normal
                                font.features: Theme.tabularFeatures
                                color: notifTile.count > 0 ? tray.colInk : tray.colMuted
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: notifMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.toggleDashboard()
                        }

                        Keys.onReturnPressed: event => { Config.toggleDashboard(); event.accepted = true; }
                        Keys.onSpacePressed: event => { Config.toggleDashboard(); event.accepted = true; }
                    }

                    Rectangle {
                        id: dndTile
                        Layout.preferredWidth: 60
                        Layout.fillWidth: false
                        Layout.fillHeight: true
                        radius: tray.innerRadius
                        color: Config.dndEnabled
                            ? tray.colAccent
                            : (dndMa.pressed ? tray.colTrayPress : (dndMa.containsMouse ? tray.colTrayHover : tray.colTray))
                        border.width: 1
                        border.color: dndTile.activeFocus
                            ? (Config.dndEnabled ? tray.colInk : tray.colAccentOnTray)
                            : (Config.dndEnabled ? "transparent" : tray.colTrayBorder)
                        activeFocusOnTab: true
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: "Jangan Ganggu"
                        Accessible.checkable: true
                        Accessible.checked: Config.dndEnabled
                        Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            MatIcon {
                                icon: Config.dndEnabled ? "notifications_off" : "notifications_paused"
                                size: 13
                                fill: Config.dndEnabled ? 1.0 : 0.0
                                color: Config.dndEnabled ? tray.colAccentText : tray.colMuted
                            }

                            Text {
                                text: Config.dndEnabled ? "DND" : "Hening"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Config.dndEnabled ? Font.Bold : Font.Medium
                                color: Config.dndEnabled ? tray.colAccentText : tray.colMuted
                            }
                        }

                        MouseArea {
                            id: dndMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Config.dndEnabled = !Config.dndEnabled
                        }

                        Keys.onReturnPressed: event => { Config.dndEnabled = !Config.dndEnabled; event.accepted = true; }
                        Keys.onSpacePressed: event => { Config.dndEnabled = !Config.dndEnabled; event.accepted = true; }
                    }
                }
            }
        }
    }
}
