import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../config"
import "../components"

Scope {
    id: root

    readonly property int maxQueuedPopups: 24
    property int _nextUid: 1

    property var activeEntry: null
    property bool activeClosing: false
    property var pendingQueue: []
    property bool stackHovered: false

    readonly property int queuedCount: pendingQueue.length
    readonly property int totalRemainingCount: (activeEntry && !activeClosing ? 1 : 0) + pendingQueue.length

    readonly property bool obscuredByOverlay: Config.dashboardOpen
        || Config.centerPopoverOpen
        || Config.launcherOpen
        || Config.powerMenuOpen
        || Config.wallpaperPickerOpen

    readonly property bool shouldShowWindow: (activeEntry !== null || pendingQueue.length > 0)
        && !Config.dndEnabled
        && !obscuredByOverlay

    // Extract clickable primary action (default/view opens on card click) vs distinct secondary buttons
    readonly property var parsedActions: {
        const acts = root.activeEntry?.rawNotif?.actions ?? [];
        let primary = null;
        const buttons = [];
        for (let i = 0; i < acts.length; i++) {
            const a = acts[i];
            if (!a) continue;
            const idLow = (a.identifier ?? "").trim().toLowerCase();
            const label = (a.text ?? "").trim();
            const isViewAction = idLow === "default"
                || idLow === "view"
                || /^(view|lihat)$/i.test(label);

            if (idLow === "default") {
                primary = a;
                continue;
            }
            if (isViewAction) {
                if (!primary) primary = a;
                continue;
            }
            if (label.length > 0 && buttons.length < 3) {
                buttons.push(a);
            }
        }
        return { primary: primary, buttons: buttons };
    }

    Connections {
        target: Config
        function onDashboardOpenChanged() {
            if (Config.dashboardOpen) root.clearAllImmediately();
        }
        function onDndEnabledChanged() {
            if (Config.dndEnabled) root.clearAllImmediately();
        }
    }

    function onNotifClosedRemotely(entry: var): void {
        if (!entry || entry.closedByServer) return;
        entry.closedByServer = true;
        if (root.activeEntry && root.activeEntry.uid === entry.uid) {
            if (!root.activeClosing) root.closeActive(false);
            return;
        }
        const nextQ = root.pendingQueue.filter(item => item.uid !== entry.uid);
        if (nextQ.length !== root.pendingQueue.length) {
            root.pendingQueue = nextQ;
        }
    }

    function computeCritical(summary: string, rawNotif: var): bool {
        return rawNotif?.urgency === NotificationUrgency.Critical
            || rawNotif?.urgency === 2
            || (!!summary && (summary.includes("Kalender") || summary.includes("Pengingat")));
    }

    function resolveArtwork(rawNotif: var, appName: string, summary: string, critical: bool): var {
        const rawImg = (rawNotif?.image ?? "").trim();
        if (rawImg.length > 0) {
            if (rawImg.startsWith("image://") || rawImg.startsWith("qsimage://") || rawImg.startsWith("file://")) {
                return { url: rawImg, isPhoto: true, fallbackIcon: "" };
            }
            if (rawImg.startsWith("/")) {
                return { url: `file://${rawImg}`, isPhoto: true, fallbackIcon: "" };
            }
            const themedImg = Quickshell.iconPath(rawImg, true);
            if (themedImg && themedImg.length > 0) {
                return { url: themedImg, isPhoto: false, fallbackIcon: "" };
            }
        }

        const rawIcon = (rawNotif?.appIcon ?? "").trim();
        if (rawIcon.length > 0) {
            if (rawIcon.startsWith("image://") || rawIcon.startsWith("qsimage://") || rawIcon.startsWith("file://")) {
                return { url: rawIcon, isPhoto: false, fallbackIcon: "" };
            }
            if (rawIcon.startsWith("/")) {
                return { url: `file://${rawIcon}`, isPhoto: false, fallbackIcon: "" };
            }
            const resolved = Quickshell.iconPath(rawIcon, true);
            if (resolved && resolved.length > 0) {
                return { url: resolved, isPhoto: false, fallbackIcon: "" };
            }
        }

        const desktopId = (rawNotif?.desktopEntry ?? "").trim();
        if (desktopId.length > 0) {
            const deIcon = Quickshell.iconPath(desktopId, true);
            if (deIcon && deIcon.length > 0) {
                return { url: deIcon, isPhoto: false, fallbackIcon: "" };
            }
        }

        const lowApp = (appName || "").trim().toLowerCase();
        const uName = (Quickshell.env("USER") || "").toLowerCase();
        if (lowApp.length > 0 && lowApp !== "system" && lowApp !== "notify-send" && (uName.length === 0 || lowApp !== uName)) {
            const guessed = Quickshell.iconPath(lowApp, true);
            if (guessed && guessed.length > 0) {
                return { url: guessed, isPhoto: false, fallbackIcon: "" };
            }
        }

        const combined = `${appName || ""} ${summary || ""}`.toLowerCase();
        let mat = "notifications";
        if (combined.includes("kalender") || combined.includes("pengingat") || combined.includes("calendar")) {
            mat = "calendar_today";
        } else if (combined.includes("screenshot") || combined.includes("hyprshot") || combined.includes("rekam") || combined.includes("record")) {
            mat = "screenshot_monitor";
        } else if (combined.includes("battery") || combined.includes("baterai") || combined.includes("daya")) {
            mat = "battery_alert";
        } else if (critical) {
            mat = "warning";
        }
        return { url: "", isPhoto: false, fallbackIcon: mat };
    }

    function normalizeFields(appName: string, summary: string, body: string, rawNotif: var): var {
        const rawApp = (appName || "").trim();
        const rawSum = (summary || "").trim();
        const rawBody = (body || "").replace(/\r\n/g, "\n").trim();
        const critical = computeCritical(rawSum, rawNotif);

        let sourceLabel = rawApp;
        if (sourceLabel.toLowerCase() === "notify-send" || sourceLabel.toLowerCase() === "system") {
            sourceLabel = "";
        }

        const sumSameAsApp = rawSum.length === 0 || (sourceLabel.length > 0 && rawSum.toLowerCase() === sourceLabel.toLowerCase());
        const headline = sumSameAsApp ? (rawBody.length > 0 ? rawBody : (sourceLabel || "Notification")) : rawSum;
        const cleanBody = (sumSameAsApp || rawBody.toLowerCase() === headline.toLowerCase()) ? "" : rawBody;
        const showSource = sourceLabel.length > 0 && sourceLabel.toLowerCase() !== headline.toLowerCase();

        const hasMarkup = cleanBody.length > 0 && /<\/?(b|i|u|br|a)(\s+[^>]*)?>/i.test(cleanBody);
        const formattedBody = hasMarkup ? cleanBody.replace(/\n/g, "<br/>") : cleanBody;

        let timeoutMs = critical ? 8000 : 5000;
        const specTimeout = rawNotif?.expireTimeout;
        if (typeof specTimeout === "number") {
            if (specTimeout === 0) {
                timeoutMs = 0; // Persistent until dismissed per Freedesktop spec
            } else if (specTimeout > 0) {
                const ms = specTimeout < 120 ? Math.round(specTimeout * 1000) : Math.round(specTimeout);
                timeoutMs = Math.max(1500, Math.min(30000, ms));
            }
        }

        const art = resolveArtwork(rawNotif, rawApp, rawSum, critical);
        return {
            sourceLabel: showSource ? sourceLabel : "",
            summaryText: headline || "Notification",
            bodyText: formattedBody,
            bodyHasMarkup: hasMarkup,
            isCritical: critical,
            artUrl: art.url,
            artIsPhoto: art.isPhoto,
            fallbackIcon: art.fallbackIcon,
            timeoutMs: timeoutMs,
            timeStr: Qt.formatDateTime(new Date(), "hh:mm")
        };
    }

    function isStillLive(entry: var): bool {
        if (!entry) return false;
        if (entry.closedByServer) return false;
        if (!entry.rawNotif) return true; // Local IPC notification has no D-Bus Notification object
        return !!entry.rawNotif.tracked;
    }

    function showPopup(appName: string, summary: string, body: string, rawNotif: var): void {
        const critical = computeCritical(summary, rawNotif);
        Config.addNotifToHistory(appName, summary, body, critical);
        if (Config.dndEnabled || Config.dashboardOpen) return;

        const norm = normalizeFields(appName, summary, body, rawNotif);
        const entry = {
            uid: root._nextUid++,
            rawNotif: rawNotif ?? null,
            closedByServer: false,
            sourceLabel: norm.sourceLabel,
            summaryText: norm.summaryText,
            bodyText: norm.bodyText,
            bodyHasMarkup: norm.bodyHasMarkup,
            isCritical: norm.isCritical,
            artUrl: norm.artUrl,
            artIsPhoto: norm.artIsPhoto,
            fallbackIcon: norm.fallbackIcon,
            timeoutMs: norm.timeoutMs,
            timeStr: norm.timeStr
        };

        if (rawNotif) {
            rawNotif.closed.connect(() => root.onNotifClosedRemotely(entry));
        }

        if (root.activeEntry === null) {
            presentEntry(entry);
            return;
        }

        const q = root.pendingQueue.slice();
        const dropped = [];
        while (q.length >= root.maxQueuedPopups) {
            const d = q.shift();
            d.closedByServer = true;
            dropped.push(d);
        }
        q.push(entry);
        root.pendingQueue = q;
        for (let i = 0; i < dropped.length; i++) {
            if (dropped[i].rawNotif) dropped[i].rawNotif.expire();
        }
    }

    function presentEntry(entry: var): void {
        exitAnim.stop();
        enterAnim.stop();
        cardSurface.enterProgress = 0.0;
        cardSurface.exitProgress = 1.0;
        root.activeClosing = false;
        root.activeEntry = entry;
        dismissTimer.stop();
        if (notifWin.surfaceReady) {
            Qt.callLater(() => {
                if (root.activeEntry && !root.activeClosing && notifWin.surfaceReady) {
                    enterAnim.restart();
                    if (root.activeEntry.timeoutMs > 0 && !root.stackHovered && !root.obscuredByOverlay) {
                        dismissTimer.restart();
                    }
                }
            });
        }
    }

    function closeActive(userDismissed: bool): void {
        if (!root.activeEntry || root.activeClosing) return;
        root.activeClosing = true;
        dismissTimer.stop();
        const active = root.activeEntry;
        active.closedByServer = true;
        if (active.rawNotif) {
            if (userDismissed) active.rawNotif.dismiss();
            else active.rawNotif.expire();
        }
        enterAnim.stop();
        exitAnim.restart();
    }

    function finishActiveExit(): void {
        const q = root.pendingQueue.slice();
        let next = null;
        while (q.length > 0) {
            const cand = q.shift();
            if (isStillLive(cand)) {
                next = cand;
                break;
            }
        }
        root.pendingQueue = q;

        if (next) {
            presentEntry(next);
        } else {
            root.activeEntry = null;
            root.activeClosing = false;
        }
    }

    function dismissAll(): void {
        const q = root.pendingQueue.slice();
        root.pendingQueue = [];
        for (let i = 0; i < q.length; i++) {
            q[i].closedByServer = true;
            if (q[i].rawNotif) q[i].rawNotif.dismiss();
        }
        closeActive(true);
    }

    function clearAllImmediately(): void {
        enterAnim.stop();
        exitAnim.stop();
        dismissTimer.stop();
        const active = root.activeEntry;
        const q = root.pendingQueue.slice();
        root.pendingQueue = [];
        root.activeEntry = null;
        root.activeClosing = false;
        root.stackHovered = false;
        if (active) {
            active.closedByServer = true;
            if (active.rawNotif) active.rawNotif.expire();
        }
        for (let i = 0; i < q.length; i++) {
            q[i].closedByServer = true;
            if (q[i].rawNotif) q[i].rawNotif.expire();
        }
    }

    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notif => {
            notif.tracked = true;
            root.showPopup(notif.appName, notif.summary, notif.body, notif);
        }
    }

    PanelWindow {
        id: notifWin

        readonly property int toastWidth: 304
        readonly property int shadowPadX: 12
        readonly property int topGap: 5
        readonly property int footerGap: 5
        readonly property int bottomShadowPad: 12

        WlrLayershell.namespace: "sora-notifications"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
        }

        margins {
            top: Config.barHeight + Config.barMarginTop + 4
        }

        // Gate Frame 1 visibility on backingWindowVisible so the card slides/fades cleanly without snap-in
        property bool surfaceReady: false
        onVisibleChanged: {
            if (!visible) {
                surfaceReady = false;
                root.stackHovered = false;
            }
        }
        onBackingWindowVisibleChanged: {
            if (backingWindowVisible && visible && !surfaceReady) {
                Qt.callLater(() => {
                    if (notifWin.visible && notifWin.backingWindowVisible) {
                        notifWin.surfaceReady = true;
                    }
                });
            }
        }
        Timer {
            interval: 110
            running: notifWin.visible && !notifWin.surfaceReady
            onTriggered: notifWin.surfaceReady = true
        }
        onSurfaceReadyChanged: {
            if (surfaceReady && root.activeEntry && !root.activeClosing) {
                enterAnim.restart();
            }
        }

        // Expand compositor surface immediately; shrink only after transitions settle to avoid Wayland jitter
        readonly property real cardHeight: root.activeEntry ? cardSurface.implicitHeight : 0
        readonly property real desiredWinHeight: Math.max(
            64,
            topGap + cardHeight + (clearAllWrap.visible ? footerGap + clearAllWrap.implicitHeight : 0) + bottomShadowPad
        )
        property real committedWinHeight: desiredWinHeight

        onDesiredWinHeightChanged: {
            if (desiredWinHeight > committedWinHeight || !visible) {
                shrinkTimer.stop();
                committedWinHeight = desiredWinHeight;
            } else {
                shrinkTimer.restart();
            }
        }
        Timer {
            id: shrinkTimer
            interval: 230
            onTriggered: notifWin.committedWinHeight = notifWin.desiredWinHeight
        }

        implicitWidth: toastWidth + shadowPadX * 2
        implicitHeight: committedWinHeight
        visible: root.shouldShowWindow
        color: "transparent"

        // Restrict pointer capture strictly to the active card + Clear All pill
        mask: Region {
            Region {
                x: Math.round(notifWin.shadowPadX + cardSurface.x)
                y: notifWin.topGap
                width: root.activeEntry ? Math.round(cardSurface.width) : 0
                height: root.activeEntry ? Math.max(0, Math.round(cardSurface.implicitHeight)) : 0
            }
            Region {
                x: Math.round((notifWin.width - clearAllBtn.width) * 0.5)
                y: Math.round(notifWin.topGap + notifWin.cardHeight + notifWin.footerGap)
                width: clearAllWrap.visible ? Math.round(clearAllBtn.width) : 0
                height: clearAllWrap.visible ? Math.round(clearAllBtn.height) : 0
            }
        }

        Timer {
            id: dismissTimer
            interval: root.activeEntry ? Math.max(1500, root.activeEntry.timeoutMs) : 5000
            running: root.activeEntry !== null
                && !root.activeClosing
                && root.activeEntry.timeoutMs > 0
                && notifWin.surfaceReady
                && !root.stackHovered
                && !root.obscuredByOverlay
            onTriggered: root.closeActive(false)
        }

        Item {
            id: stageWrap
            x: notifWin.shadowPadX
            y: notifWin.topGap
            width: notifWin.toastWidth
            height: Math.max(0, notifWin.committedWinHeight - notifWin.topGap)

            HoverHandler {
                id: stackHoverHandler
                onHoveredChanged: root.stackHovered = hovered && notifWin.visible
            }

            RectangularShadow {
                anchors.fill: cardSurface
                radius: cardSurface.radius
                blur: 12
                spread: 0
                offset.y: 3
                color: Qt.alpha("#000000", Theme.isDarkMode ? 0.36 : 0.10)
                opacity: cardSurface.opacity * (cardSurface.exitProgress > 0.5 ? 1.0 : 0.0)
                visible: root.activeEntry !== null
            }

            Rectangle {
                id: cardSurface

                property real enterProgress: 0.0
                property real exitProgress: 1.0
                property real pressScale: cardClickArea.pressed ? 0.985 : 1.0

                Behavior on pressScale {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }

                NumberAnimation {
                    id: enterAnim
                    target: cardSurface
                    property: "enterProgress"
                    to: 1.0
                    duration: 180
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    id: exitAnim
                    target: cardSurface
                    property: "exitProgress"
                    to: 0.0
                    duration: 150
                    easing.type: Easing.OutCubic
                    onFinished: root.finishActiveExit()
                }

                readonly property bool hovered: stackHoverHandler.hovered
                readonly property bool isCritical: root.activeEntry?.isCritical ?? false
                readonly property string sourceLabel: root.activeEntry?.sourceLabel ?? ""
                readonly property string summaryText: root.activeEntry?.summaryText ?? ""
                readonly property string bodyText: root.activeEntry?.bodyText ?? ""
                readonly property bool bodyHasMarkup: root.activeEntry?.bodyHasMarkup ?? false
                readonly property string artUrl: root.activeEntry?.artUrl ?? ""
                readonly property bool artIsPhoto: root.activeEntry?.artIsPhoto ?? false
                readonly property string fallbackIcon: root.activeEntry?.fallbackIcon ?? "notifications"
                readonly property int timeoutMs: root.activeEntry?.timeoutMs ?? 5000
                readonly property bool canRunPrimary: root.parsedActions.primary !== null
                readonly property bool isSingleLine: bodyText.length === 0 && root.parsedActions.buttons.length === 0

                TextMetrics {
                    id: titleMetrics
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    text: cardSurface.summaryText
                        + (cardSurface.sourceLabel.length > 0 ? " · " + cardSurface.sourceLabel : "")
                        + (root.queuedCount > 0 ? " +" + root.queuedCount : "")
                }

                TextMetrics {
                    id: bodyMetrics
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    text: cardSurface.bodyText.replace(/<[^>]*>/g, "")
                }

                readonly property int naturalContentW: Math.max(
                    Math.ceil(titleMetrics.advanceWidth),
                    cardSurface.bodyText.length > 0 ? Math.min(236, Math.ceil(bodyMetrics.advanceWidth)) : 0,
                    root.parsedActions.buttons.length > 0 ? 186 : 0
                )

                visible: root.activeEntry !== null
                width: Math.min(notifWin.toastWidth, Math.max(168, naturalContentW + mediaBox.implicitWidth + 32))
                x: Math.round((notifWin.toastWidth - width) * 0.5)
                implicitHeight: isSingleLine ? 34 : Math.max(44, cardRow.implicitHeight + 14)
                height: implicitHeight
                y: (1.0 - enterProgress) * -8 + (1.0 - exitProgress) * -6
                opacity: Math.min(enterProgress, exitProgress * exitProgress)
                scale: (0.97 + 0.03 * enterProgress) * pressScale
                radius: isSingleLine ? 17 : 16
                color: Qt.alpha(hovered ? Theme.surfaceContainerHigh : Theme.surface, Theme.barOpacity)
                border.width: isCritical ? 1 : 0
                border.color: isCritical ? Qt.alpha(Theme.urgent, 0.75) : "transparent"

                Behavior on color { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }

                Accessible.role: Accessible.Pane
                Accessible.name: `${sourceLabel ? sourceLabel + ": " : ""}${summaryText}${canRunPrimary ? " (click to open)" : ""}`

                MouseArea {
                    id: cardClickArea
                    anchors.fill: parent
                    z: 0
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (root.activeClosing || !root.activeEntry) return;
                        if (mouse.button === Qt.LeftButton && root.parsedActions.primary) {
                            root.parsedActions.primary.invoke();
                            if (!root.activeEntry?.rawNotif?.resident) {
                                root.closeActive(false);
                            }
                        } else {
                            root.closeActive(true);
                        }
                    }
                }

                RowLayout {
                    id: cardRow
                    anchors.verticalCenter: cardSurface.isSingleLine ? parent.verticalCenter : undefined
                    anchors.top: cardSurface.isSingleLine ? undefined : parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: cardSurface.isSingleLine ? 0 : 7
                    anchors.leftMargin: 10
                    anchors.rightMargin: 11
                    spacing: 8
                    z: 1

                    Item {
                        id: mediaBox
                        Layout.alignment: cardSurface.isSingleLine || root.parsedActions.buttons.length === 0
                            ? Qt.AlignVCenter
                            : Qt.AlignTop
                        Layout.topMargin: (cardSurface.isSingleLine || root.parsedActions.buttons.length === 0) ? 0 : 2
                        readonly property bool hasPhoto: cardSurface.artUrl.length > 0 && cardSurface.artIsPhoto && photoImg.status !== Image.Error
                        readonly property bool hasAppIcon: cardSurface.artUrl.length > 0 && !cardSurface.artIsPhoto && appIconImg.status === Image.Ready
                        implicitWidth: hasPhoto ? 26 : 20
                        implicitHeight: implicitWidth

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: 13
                            color: Theme.surfaceContainerHigh
                            border.width: 0
                            visible: mediaBox.hasPhoto

                            Image {
                                id: photoImg
                                anchors.fill: parent
                                source: cardSurface.artIsPhoto ? cardSurface.artUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 56
                                sourceSize.height: 56
                            }
                        }

                        // Native app icon rendered directly without a nested squircle box
                        IconImage {
                            id: appIconImg
                            anchors.centerIn: parent
                            implicitSize: 20
                            asynchronous: true
                            source: (!cardSurface.artIsPhoto && cardSurface.artUrl.length > 0) ? cardSurface.artUrl : ""
                            visible: mediaBox.hasAppIcon
                        }

                        // Circular badge for system/fallback icons (matching Clock.qml & CenterIsland motif)
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            visible: !mediaBox.hasPhoto && !mediaBox.hasAppIcon
                            color: cardSurface.isCritical
                                ? Qt.alpha(Theme.urgent, 0.20)
                                : (Theme.isDarkMode ? Qt.alpha(Theme.primary, 0.16) : Theme.primary)

                            MatIcon {
                                anchors.centerIn: parent
                                icon: cardSurface.fallbackIcon.length > 0
                                    ? cardSurface.fallbackIcon
                                    : (cardSurface.isCritical ? "warning" : "notifications")
                                size: 13
                                fill: 1.0
                                color: cardSurface.isCritical
                                    ? Theme.urgentInk
                                    : (Theme.isDarkMode ? Theme.primary : Theme.onPrimary)
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        // Line 1: Headline + Inline App Source + Queue Count
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                visible: cardSurface.isCritical
                                width: 5
                                height: 5
                                radius: 2.5
                                color: Theme.urgentInk
                            }

                            Text {
                                text: cardSurface.summaryText
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: cardSurface.isCritical ? Theme.urgentInk : Theme.text
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: cardSurface.sourceLabel.length === 0
                                Layout.maximumWidth: cardSurface.sourceLabel.length > 0 ? 175 : 245
                            }

                            Text {
                                visible: cardSurface.sourceLabel.length > 0
                                text: `· ${cardSurface.sourceLabel}`
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.subtext
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: root.queuedCount > 0 && !cardSurface.hovered
                                text: `+${root.queuedCount}`
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.features: Theme.tabularFeatures
                                color: Theme.primary
                            }
                        }

                        // Line 2: Body Copy (max 2 lines)
                        Text {
                            visible: cardSurface.bodyText.length > 0
                            text: cardSurface.bodyText
                            textFormat: cardSurface.bodyHasMarkup ? Text.StyledText : Text.PlainText
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.subtext
                            linkColor: Theme.accentInk
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            lineHeight: 1.15
                            Layout.fillWidth: true
                            onLinkActivated: link => {
                                Qt.openUrlExternally(link);
                                if (!root.activeEntry?.rawNotif?.resident) {
                                    root.closeActive(false);
                                }
                            }
                        }

                        // Optional Action Pills
                        Flow {
                            visible: root.parsedActions.buttons.length > 0
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 5

                            Repeater {
                                model: root.parsedActions.buttons

                                delegate: Rectangle {
                                    id: actBtn
                                    required property var modelData
                                    readonly property string actionLabel: modelData?.text ?? ""

                                    implicitWidth: Math.min(150, actTxt.implicitWidth + 16)
                                    implicitHeight: 21
                                    radius: 10.5
                                    color: actMouse.containsMouse ? Theme.primary : Theme.surfaceContainerHigh
                                    scale: actMouse.pressed ? 0.96 : 1.0

                                    Behavior on color { ColorAnimation { duration: 110 } }
                                    Behavior on scale { NumberAnimation { duration: 90 } }

                                    Accessible.role: Accessible.Button
                                    Accessible.name: actBtn.actionLabel

                                    Text {
                                        id: actTxt
                                        anchors.centerIn: parent
                                        width: Math.min(implicitWidth, 134)
                                        text: actBtn.actionLabel
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: actMouse.containsMouse ? Theme.onPrimary : Theme.text
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    MouseArea {
                                        id: actMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.activeClosing || !root.activeEntry) return;
                                            if (actBtn.modelData) actBtn.modelData.invoke();
                                            if (!root.activeEntry?.rawNotif?.resident) {
                                                root.closeActive(false);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Hover-only dismiss control (keeps toast clean when unhovered)
                Rectangle {
                    id: closeBtn
                    anchors.top: cardSurface.isSingleLine ? undefined : parent.top
                    anchors.verticalCenter: cardSurface.isSingleLine ? parent.verticalCenter : undefined
                    anchors.right: parent.right
                    anchors.topMargin: 6
                    anchors.rightMargin: 7
                    width: 18
                    height: 18
                    radius: 9
                    z: 2
                    opacity: cardSurface.hovered ? 1.0 : 0.0
                    visible: opacity > 0.01
                    color: closeMouse.containsMouse ? Qt.alpha(Theme.urgentInk, 0.18) : Theme.surfaceContainerHighest
                    scale: closeMouse.pressed ? 0.90 : 1.0

                    Behavior on opacity { NumberAnimation { duration: 110 } }
                    Behavior on color { ColorAnimation { duration: 110 } }

                    Accessible.role: Accessible.Button
                    Accessible.name: "Dismiss notification"

                    MatIcon {
                        anchors.centerIn: parent
                        icon: "close"
                        size: 12
                        color: closeMouse.containsMouse ? Theme.urgentInk : Theme.subtext
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeActive(true)
                    }
                }
            }

            // Queue Footer Control (appears directly beneath the card only when additional notifications wait in queue)
            Item {
                id: clearAllWrap
                visible: root.queuedCount >= 1 && root.activeEntry !== null && notifWin.surfaceReady
                anchors.top: cardSurface.bottom
                anchors.topMargin: notifWin.footerGap
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: 22
                height: 22

                RectangularShadow {
                    anchors.fill: clearAllBtn
                    radius: clearAllBtn.radius
                    blur: 8
                    spread: 0
                    offset.y: 2
                    color: Qt.alpha("#000000", Theme.isDarkMode ? 0.28 : 0.08)
                }

                Rectangle {
                    id: clearAllBtn
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: clearRow.implicitWidth + 14
                    width: implicitWidth
                    implicitHeight: 22
                    height: 22
                    radius: 11
                    color: clearMouse.containsMouse
                        ? Theme.surfaceContainerHigh
                        : Qt.alpha(Theme.surface, Theme.barOpacity)
                    border.width: 0
                    scale: clearMouse.pressed ? 0.96 : 1.0

                    Behavior on color { ColorAnimation { duration: 110 } }
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Accessible.role: Accessible.Button
                    Accessible.name: `Clear ${root.totalRemainingCount} notifications`

                    Row {
                        id: clearRow
                        anchors.centerIn: parent
                        spacing: 4

                        MatIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "clear_all"
                            size: 12
                            color: clearMouse.containsMouse ? Theme.urgentInk : Theme.subtext
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: `Clear ${root.totalRemainingCount}`
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.features: Theme.tabularFeatures
                            color: clearMouse.containsMouse ? Theme.urgentInk : Theme.subtext
                        }
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissAll()
                    }
                }
            }
        }
    }
}
