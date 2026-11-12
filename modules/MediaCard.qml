import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import "../config"
import "../components"
import "../services"

Item {
    id: root

    width: 688
    height: 320
    clip: true

    // ========================================================================
    // MPRIS MULTI-PLAYER SELECTION (PREFER PLAYING -> SPOTIFY -> FIRST)
    // ========================================================================
    readonly property var playerList: Mpris.players.values ?? []
    readonly property int playerCount: playerList ? playerList.length : 0
    property int manualPlayerIndex: -1
    readonly property int resolvedPlayerIndex: {
        const list = playerList;
        const n = list ? list.length : 0;
        if (n === 0) return -1;
        if (manualPlayerIndex >= 0 && manualPlayerIndex < n) return manualPlayerIndex;
        for (let i = 0; i < n; i++) {
            if (list[i]?.playbackState === MprisPlaybackState.Playing) return i;
        }
        for (let i = 0; i < n; i++) {
            if ((list[i]?.identity ?? "").toLowerCase().includes("spotify")) return i;
        }
        return 0;
    }
    readonly property MprisPlayer player: resolvedPlayerIndex >= 0 ? (playerList[resolvedPlayerIndex] ?? null) : null
    readonly property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing
    readonly property string playerIdentity: player?.identity ?? ""
    readonly property bool isSpotify: playerIdentity.toLowerCase().includes("spotify")
    readonly property string rawTitle: player?.trackTitle ?? ""
    readonly property bool hasActiveTrack: player !== null && rawTitle.trim().length > 0
    readonly property string trackTitle: hasActiveTrack ? rawTitle : "Tidak ada lagu"
    readonly property string trackArtist: (player?.trackArtist && player.trackArtist.length > 0)
        ? player.trackArtist
        : (hasActiveTrack ? "Artis tidak diketahui" : "Putar musik di Spotify atau pemutar media")
    readonly property string trackAlbum: player?.trackAlbum ?? ""
    readonly property bool showAlbumLine: hasActiveTrack
        && trackAlbum.length > 0
        && trackAlbum !== trackTitle
        && trackAlbum.toLowerCase() !== trackArtist.toLowerCase()
    readonly property string artUrl: player?.trackArtUrl ?? ""

    property real pos: player?.position ?? 0
    readonly property real len: Math.max(1, player?.length ?? 1)
    readonly property real progressRatio: hasActiveTrack && len > 1 ? Math.max(0.0, Math.min(1.0, pos / len)) : 0.0
    property bool scrubbing: false
    property real scrubRatio: 0.0
    readonly property real displayRatio: scrubbing ? scrubRatio : progressRatio
    readonly property real displayPos: scrubbing ? (scrubRatio * len) : pos

    readonly property bool shuffleActive: player?.shuffle ?? false
    readonly property int loopMode: player ? player.loopState : MprisLoopState.None
    readonly property bool repeatActive: loopMode !== MprisLoopState.None

    // ========================================================================
    // LYRICS STATE & ASYNC SEQUENCE GUARD
    // ========================================================================
    property var parsedLyrics: []
    property bool isSyncedLyrics: false
    property bool lyricsLoading: false
    property bool lyricsFound: false
    property bool lyricsError: false
    property int activeLyricIndex: 0
    property string lastFetchedKey: ""
    property int _lyricReqSeq: 0
    property var _activeXhr: null

    Timer {
        id: posPollTimer
        interval: 220
        running: root.isPlaying && Config.mediaPopoverOpen && !root.scrubbing
        repeat: true
        onTriggered: {
            if (root.player) root.pos = root.player.position;
        }
    }

    Timer {
        id: lyricsTimeoutTimer
        interval: 8000
        repeat: false
        onTriggered: {
            if (root.lyricsLoading) {
                root._lyricReqSeq++;
                if (root._activeXhr) {
                    try { root._activeXhr.abort(); } catch (e) {}
                    root._activeXhr = null;
                }
                root.lyricsLoading = false;
                root.lyricsFound = false;
                root.lyricsError = true;
            }
        }
    }

    onPlayerChanged: {
        manualPlayerIndex = (playerCount > 0 && manualPlayerIndex >= playerCount) ? -1 : manualPlayerIndex;
        pos = player ? player.position : 0;
        checkAndFetchLyrics(false);
    }

    onRawTitleChanged: checkAndFetchLyrics(false)
    onTrackArtistChanged: checkAndFetchLyrics(false)

    Connections {
        target: Config
        function onMediaPopoverOpenChanged() {
            if (Config.mediaPopoverOpen) {
                if (root.player) root.pos = root.player.position;
                if (!root.lyricsFound && !root.lyricsLoading) {
                    root.checkAndFetchLyrics(true);
                }
                root.updateActiveLyric(true, true);
            }
        }
    }

    Component.onCompleted: {
        if (Config.mediaPopoverOpen) checkAndFetchLyrics(true);
    }

    // ========================================================================
    // HELPERS: PLAYBACK, PLAYER SWITCHING, LYRICS FETCHING & PARSING
    // ========================================================================
    function cyclePlayer(): void {
        if (playerCount <= 1) return;
        manualPlayerIndex = (resolvedPlayerIndex + 1) % playerCount;
    }

    function cycleLoopState(): void {
        if (!player || !player.loopSupported) return;
        if (player.loopState === MprisLoopState.None) player.loopState = MprisLoopState.Playlist;
        else if (player.loopState === MprisLoopState.Playlist) player.loopState = MprisLoopState.Track;
        else player.loopState = MprisLoopState.None;
    }

    function formatTime(sec: real): string {
        if (!sec || sec <= 0 || !isFinite(sec)) return "0:00";
        const total = Math.floor(sec);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return `${m}:${s < 10 ? "0" + s : s}`;
    }

    function seekToSec(targetPos: real): void {
        if (!player || !player.canSeek) return;
        const clamped = Math.max(0.0, Math.min(len, targetPos));
        player.position = clamped;
        pos = clamped;
        updateActiveLyric(true);
    }

    function seekToRatio(ratio: real): void {
        const clamped = Math.max(0.0, Math.min(1.0, ratio));
        seekToSec(clamped * len);
    }

    function seekBy(deltaSec: real): void {
        seekToSec(pos + deltaSec);
    }

    function lineTime(item: var): real {
        if (!item) return 0;
        if (isSyncedLyrics) return item.time;
        return item.ratio * Math.max(60, len) * 0.92;
    }

    function updateActiveLyric(forceUpdate = false, instant = false): void {
        if (parsedLyrics.length === 0) return;
        let idx = 0;
        for (let i = 0; i < parsedLyrics.length; i++) {
            if (lineTime(parsedLyrics[i]) <= pos + 0.15) idx = i;
            else break;
        }
        if (idx !== activeLyricIndex || forceUpdate) {
            activeLyricIndex = idx;
            if (lyricsList && lyricsList.count > 0 && lyricsList.height > 0) {
                lyricScrollAnim.stop();
                const prevY = lyricsList.contentY;
                lyricsList.positionViewAtIndex(idx, ListView.Center);
                const minY = lyricsList.originY;
                const maxY = lyricsList.originY + Math.max(0, lyricsList.contentHeight - lyricsList.height);
                const activeItem = lyricsList.itemAtIndex(idx);
                const rawTargetY = activeItem
                    ? (activeItem.y + activeItem.height * 0.5 - lyricsList.height * 0.39)
                    : (lyricsList.contentY + Math.round(lyricsList.height * 0.11));
                const targetY = Math.max(minY, Math.min(maxY, Math.round(rawTargetY)));
                if (instant) {
                    lyricsList.contentY = targetY;
                } else {
                    lyricsList.contentY = prevY;
                    lyricScrollAnim.to = targetY;
                    lyricScrollAnim.restart();
                }
            }
        }
    }

    onPosChanged: updateActiveLyric(false)

    function parseLrc(lrcText: string): var {
        const lines = lrcText.split("\n");
        const list = [];
        for (let i = 0; i < lines.length; i++) {
            const match = lines[i].trim().match(/^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/);
            if (match) {
                const time = (parseInt(match[1], 10) * 60) + parseFloat(match[2]);
                const text = match[3].trim();
                if (text.length > 0) list.push({ time: time, ratio: 0, text: text });
            }
        }
        return list;
    }

    function parsePlainToTimed(plainText: string): var {
        const rawLines = plainText.split("\n");
        const clean = [];
        for (let i = 0; i < rawLines.length; i++) {
            const t = rawLines[i].trim();
            if (t.length > 0) clean.push(t);
        }
        const total = Math.max(1, clean.length);
        const list = [];
        for (let i = 0; i < clean.length; i++) {
            list.push({ time: 0, ratio: i / total, text: clean[i] });
        }
        return list;
    }

    function extractLyricsResult(payload: var): var {
        if (!payload) return null;
        const items = Array.isArray(payload) ? payload : [payload];
        for (let i = 0; i < items.length; i++) {
            if (items[i]?.syncedLyrics && items[i].syncedLyrics.length > 0) {
                const synced = parseLrc(items[i].syncedLyrics);
                if (synced.length > 0) return { synced: true, lines: synced };
            }
        }
        for (let j = 0; j < items.length; j++) {
            if (items[j]?.plainLyrics && items[j].plainLyrics.length > 0) {
                const plain = parsePlainToTimed(items[j].plainLyrics);
                if (plain.length > 0) return { synced: false, lines: plain };
            }
        }
        return null;
    }

    function runLyricsStep(step: int, seqId: int, cleanTitle: string, hadNetError: bool): void {
        if (seqId !== _lyricReqSeq) return;
        let url = "";
        if (step === 0) {
            url = `https://lrclib.net/api/get?track_name=${encodeURIComponent(rawTitle)}&artist_name=${encodeURIComponent(trackArtist)}`;
        } else if (step === 1) {
            url = `https://lrclib.net/api/search?q=${encodeURIComponent(cleanTitle + " " + trackArtist)}`;
        } else if (step === 2 && cleanTitle.length > 0 && cleanTitle !== `${cleanTitle} ${trackArtist}`.trim()) {
            url = `https://lrclib.net/api/search?q=${encodeURIComponent(cleanTitle)}`;
        } else {
            lyricsTimeoutTimer.stop();
            _activeXhr = null;
            lyricsLoading = false;
            lyricsFound = false;
            lyricsError = hadNetError;
            return;
        }

        const xhr = new XMLHttpRequest();
        _activeXhr = xhr;
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (seqId !== root._lyricReqSeq) return;
            let stepError = hadNetError;
            if (xhr.status === 200) {
                try {
                    const data = JSON.parse(xhr.responseText);
                    const picked = root.extractLyricsResult(data);
                    if (picked) {
                        lyricsTimeoutTimer.stop();
                        root._activeXhr = null;
                        root.isSyncedLyrics = picked.synced;
                        root.parsedLyrics = picked.lines;
                        root.lyricsFound = true;
                        root.lyricsError = false;
                        root.lyricsLoading = false;
                        root.updateActiveLyric(true);
                        return;
                    }
                } catch (e) {
                    stepError = true;
                }
            } else if (xhr.status === 0 || xhr.status >= 500) {
                stepError = true;
            }
            root.runLyricsStep(step + 1, seqId, cleanTitle, stepError);
        };
        xhr.send();
    }

    function checkAndFetchLyrics(force = false): void {
        const key = `${rawTitle}::${trackArtist}`;
        if (!hasActiveTrack) {
            _lyricReqSeq++;
            lyricsTimeoutTimer.stop();
            if (_activeXhr) {
                try { _activeXhr.abort(); } catch (e) {}
                _activeXhr = null;
            }
            lyricsLoading = false;
            lyricsFound = false;
            lyricsError = false;
            isSyncedLyrics = false;
            parsedLyrics = [];
            activeLyricIndex = 0;
            lastFetchedKey = "";
            return;
        }
        if (key !== lastFetchedKey) {
            lyricsFound = false;
            lyricsError = false;
            isSyncedLyrics = false;
            parsedLyrics = [];
            activeLyricIndex = 0;
        }
        if (!force && !Config.mediaPopoverOpen) return;
        if (!force && key === lastFetchedKey && (lyricsFound || lyricsLoading)) return;

        lastFetchedKey = key;
        const seqId = ++_lyricReqSeq;
        if (_activeXhr) {
            try { _activeXhr.abort(); } catch (e) {}
            _activeXhr = null;
        }
        lyricsLoading = true;
        lyricsError = false;
        lyricsTimeoutTimer.restart();

        let cleanTitle = rawTitle.replace(/[\(\[\-].*?[\)\]\-]/g, "").trim();
        if (cleanTitle.length === 0) cleanTitle = rawTitle;
        runLyricsStep(0, seqId, cleanTitle, false);
    }

    // ========================================================================
    // REUSABLE MATTE CONTROL BUTTON (OPAQUE TOKENS + KEYBOARD ACCESSIBLE)
    // ========================================================================
    component BentoIconBtn: Rectangle {
        id: btn
        property string icon: ""
        property int iconSize: 16
        property real iconFill: 0.0
        property int size: 28
        property int btnRadius: 7
        property bool active: false
        property bool urgent: false
        property bool btnEnabled: true
        property bool focal: false
        property string accessName: ""
        signal triggered()

        width: size
        height: size
        radius: btnRadius
        activeFocusOnTab: btnEnabled && Config.mediaPopoverOpen
        opacity: btnEnabled ? 1.0 : 0.36
        scale: btnMouse.pressed && btnEnabled ? 0.92 : 1.0

        color: {
            if (focal) {
                if (!btnEnabled) return Theme.surfaceContainer;
                return btnHover.hovered ? Qt.lighter(Theme.accent, 1.07) : Theme.accent;
            }
            if (active && urgent) return btnHover.hovered ? Qt.lighter(Theme.urgent, 1.07) : Theme.urgent;
            // Non-focal active: outlined, not filled — keeps Play/Pause as the sole accent anchor
            if (active) return btnHover.hovered ? Theme.surfaceContainerLow : "transparent";
            if (!btnEnabled) return "transparent";
            return btnHover.hovered ? Theme.surfaceContainerLow : "transparent";
        }
        border.width: (activeFocus || (active && !focal && !urgent)) ? 1.5 : 0
        border.color: (active && !focal && !urgent) ? Theme.accentInk : (focal || active) ? Theme.text : Theme.accentInk

        Accessible.role: Accessible.Button
        Accessible.name: accessName.length > 0 ? accessName : icon

        Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

        HoverHandler { id: btnHover }

        MatIcon {
            anchors.centerIn: parent
            icon: btn.icon
            size: btn.iconSize
            fill: btn.iconFill
            color: {
                if (btn.focal) return btn.btnEnabled ? Theme.accentOnFill : Theme.subtext;
                if (btn.active && btn.urgent) return Theme.isDarkMode ? "#171A1C" : "#F8FAFA";
                if (btn.active) return Theme.accentInk;
                if (!btn.btnEnabled) return Theme.subtext;
                return (btnHover.hovered || btn.activeFocus) ? Theme.text : Theme.subtext;
            }
        }

        Keys.onReturnPressed: event => {
            if (btn.btnEnabled) { btn.triggered(); event.accepted = true; }
        }
        Keys.onSpacePressed: event => {
            if (btn.btnEnabled) { btn.triggered(); event.accepted = true; }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            enabled: btn.btnEnabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: btn.triggered()
        }
    }

    // ========================================================================
    // OUTER MASK & BENTO CANVAS (MATCHES ProfileCard.qml 688x320 GEOMETRY)
    // ========================================================================
    Rectangle {
        id: innerMask
        anchors.fill: parent
        anchors.margins: 1
        radius: 13
        color: "#ffffff"
        visible: false
        layer.enabled: true
    }

    Item {
        id: bentoCanvas
        anchors.fill: parent
        anchors.margins: 1
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: innerMask
            maskSpreadAtMin: 1.0
            maskThresholdMin: 0.5
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // ================================================================
            // 1. LEFT TRACK CARD (204 x 298) - 1:1 COVER + METADATA + SOURCE
            // ================================================================
            Rectangle {
                id: trackCard
                Layout.preferredWidth: 204
                Layout.fillHeight: true
                radius: 10
                color: Theme.surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 10
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.bottomMargin: 8
                    spacing: 5

                    // 1:1 Uncropped Square Album Art (184 x 184)
                    Rectangle {
                        id: artBox
                        Layout.preferredWidth: 184
                        Layout.preferredHeight: 184
                        radius: 7
                        color: Theme.surfaceContainerLow

                        MatIcon {
                            anchors.centerIn: parent
                            icon: "album"
                            size: 46
                            color: Theme.subtext
                            opacity: 0.48
                            visible: albumArt.status !== Image.Ready
                        }

                        Rectangle {
                            id: artMask
                            anchors.fill: parent
                            radius: 7
                            color: "#ffffff"
                            visible: false
                            layer.enabled: true
                        }

                        Item {
                            anchors.fill: parent
                            visible: albumArt.status === Image.Ready
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: artMask
                                maskSpreadAtMin: 1.0
                                maskThresholdMin: 0.5
                            }

                            Image {
                                id: albumArt
                                anchors.fill: parent
                                source: root.artUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                mipmap: true
                            }
                        }

                        // Subtle hairline keeps light covers separated from white card
                        Rectangle {
                            anchors.fill: parent
                            radius: 7
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.outline
                        }
                    }

                    // Clean Metadata Block (Title -> Artist -> Conditional Album)
                    Column {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        Text {
                            id: titleText
                            width: parent.width
                            text: root.trackTitle
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            lineHeight: 1.15
                            lineHeightMode: Text.ProportionalHeight
                            color: root.hasActiveTrack ? Theme.text : Theme.subtext
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.trackArtist
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.subtext
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: root.showAlbumLine && titleText.lineCount === 1
                            text: root.trackAlbum
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.subtext
                            opacity: 0.90
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.outline
                    }

                    // Bottom Source Footer (Raise Player + Multi-Player Switcher)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        spacing: 4

                        Rectangle {
                            id: raiseBtn
                            readonly property bool canTrigger: root.player !== null && root.player.canRaise
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            radius: 6
                            activeFocusOnTab: canTrigger && Config.mediaPopoverOpen
                            color: canTrigger && raiseHover.hovered ? Theme.surfaceContainerLow : "transparent"
                            border.width: activeFocus ? 1.5 : 0
                            border.color: Theme.accentInk
                            Accessible.role: Accessible.Button
                            Accessible.name: canTrigger ? `Buka jendela ${root.isSpotify ? "Spotify" : root.playerIdentity}` : "Sumber media"

                            HoverHandler { id: raiseHover }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 3
                                anchors.rightMargin: 4
                                spacing: 5

                                Image {
                                    visible: root.hasActiveTrack && root.isSpotify
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                    source: `${Quickshell.env("HOME")}/.config/quickshell/sora/assets/spotify.svg`
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                }

                                MatIcon {
                                    visible: !(root.hasActiveTrack && root.isSpotify)
                                    icon: "music_note"
                                    size: 14
                                    color: (raiseBtn.canTrigger && raiseHover.hovered) ? Theme.accentInk : Theme.subtext
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.player
                                        ? (root.isSpotify ? "Spotify" : (root.playerIdentity.length > 0 ? root.playerIdentity : "Pemutar Media"))
                                        : "Tidak ada pemutar"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: (raiseBtn.canTrigger && (raiseHover.hovered || raiseBtn.activeFocus)) ? Theme.text : Theme.subtext
                                    elide: Text.ElideRight
                                }

                                MatIcon {
                                    visible: raiseBtn.canTrigger && (raiseHover.hovered || raiseBtn.activeFocus)
                                    icon: "open_in_new"
                                    size: 12
                                    color: Theme.accentInk
                                }
                            }

                            function triggerRaise(): void {
                                if (raiseBtn.canTrigger) {
                                    root.player.raise();
                                    Config.closeAllOverlays();
                                }
                            }

                            Keys.onReturnPressed: event => {
                                if (raiseBtn.canTrigger) { triggerRaise(); event.accepted = true; }
                            }
                            Keys.onSpacePressed: event => {
                                if (raiseBtn.canTrigger) { triggerRaise(); event.accepted = true; }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: raiseBtn.canTrigger
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: raiseBtn.triggerRaise()
                            }
                        }

                        Rectangle {
                            id: switchPlayerBtn
                            visible: root.playerCount > 1
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: switchRow.implicitWidth + 10
                            radius: 6
                            activeFocusOnTab: visible && Config.mediaPopoverOpen
                            color: switchHover.hovered ? Theme.surfaceContainerLow : Theme.surfaceContainer
                            border.width: activeFocus ? 1.5 : 0
                            border.color: Theme.accentInk
                            Accessible.role: Accessible.Button
                            Accessible.name: "Ganti pemutar media"

                            HoverHandler { id: switchHover }

                            Row {
                                id: switchRow
                                anchors.centerIn: parent
                                spacing: 3

                                MatIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: "swap_horiz"
                                    size: 13
                                    color: switchHover.hovered ? Theme.accentInk : Theme.text
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: `${root.resolvedPlayerIndex + 1}/${root.playerCount}`
                                    font.family: Theme.fontFamily
                                    font.features: Theme.tabularFeatures
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }
                            }

                            Keys.onReturnPressed: event => { root.cyclePlayer(); event.accepted = true; }
                            Keys.onSpacePressed: event => { root.cyclePlayer(); event.accepted = true; }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cyclePlayer()
                            }
                        }
                    }
                }
            }

            // ================================================================
            // 2. RIGHT COLUMN (454 x 298) - LYRICS CARD + TRANSPORT CONSOLE CARD
            // ================================================================
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // ------------------------------------------------------------
                // TOP-RIGHT CARD: REAL-TIME LYRICS & REAL STATES (454 x 202)
                // ------------------------------------------------------------
                Rectangle {
                    id: lyricsCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Theme.surface

                    // Card Header
                    Item {
                        id: lyricsHeader
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 36

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: root.hasActiveTrack ? "Lirik" : "Pemutar Media"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: Theme.text
                            }

                            Text {
                                visible: root.lyricsFound && root.isSyncedLyrics
                                Layout.alignment: Qt.AlignVCenter
                                text: "Tersinkron"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.accentInk
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                visible: root.lyricsFound && root.parsedLyrics.length > 0
                                Layout.alignment: Qt.AlignVCenter
                                text: `${String(root.activeLyricIndex + 1).padStart(2, '0')} / ${String(root.parsedLyrics.length).padStart(2, '0')}`
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.features: Theme.tabularFeatures
                                color: Theme.subtext
                            }

                            BentoIconBtn {
                                visible: root.hasActiveTrack
                                Layout.alignment: Qt.AlignVCenter
                                size: 22
                                btnRadius: 6
                                icon: "refresh"
                                iconSize: 14
                                btnEnabled: root.hasActiveTrack && !root.lyricsLoading
                                accessName: "Muat ulang lirik"
                                onTriggered: root.checkAndFetchLyrics(true)
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            height: 1
                            color: Theme.outline
                        }
                    }

                    // Lyrics Viewport (Empty / Loading / Error / Not Found / ListView)
                    Item {
                        id: lyricsViewport
                        anchors.top: lyricsHeader.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        clip: true

                        // Empty State
                        ColumnLayout {
                            visible: !root.hasActiveTrack
                            anchors.centerIn: parent
                            spacing: 5

                            MatIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "music_note"
                                size: 26
                                color: Theme.subtext
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Tidak ada pemutar aktif"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Putar lagu untuk menampilkan lirik dan kontrol pemutaran"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.subtext
                            }
                        }

                        // Loading State
                        ColumnLayout {
                            visible: root.hasActiveTrack && root.lyricsLoading
                            anchors.centerIn: parent
                            spacing: 6

                            MatIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "sync"
                                size: 24
                                color: Theme.accentInk
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Mencari lirik..."
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.subtext
                            }
                        }

                        // Error State (Network/API Failure with Keyboard-Focusable Retry)
                        ColumnLayout {
                            visible: root.hasActiveTrack && !root.lyricsLoading && !root.lyricsFound && root.lyricsError
                            anchors.centerIn: parent
                            spacing: 6

                            MatIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "wifi_off"
                                size: 22
                                color: Theme.urgentInk
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Lirik gagal dimuat"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Theme.text
                            }

                            Rectangle {
                                id: retryLyricsBtn
                                Layout.alignment: Qt.AlignHCenter
                                height: 24
                                implicitWidth: retryText.implicitWidth + 16
                                radius: 6
                                activeFocusOnTab: visible && Config.mediaPopoverOpen
                                color: retryHover.hovered ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                border.width: activeFocus ? 1.5 : 0
                                border.color: Theme.accentInk
                                Accessible.role: Accessible.Button
                                Accessible.name: "Muat ulang lirik"

                                HoverHandler { id: retryHover }

                                Text {
                                    id: retryText
                                    anchors.centerIn: parent
                                    text: "Muat ulang"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }

                                Keys.onReturnPressed: event => { root.checkAndFetchLyrics(true); event.accepted = true; }
                                Keys.onSpacePressed: event => { root.checkAndFetchLyrics(true); event.accepted = true; }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.checkAndFetchLyrics(true)
                                }
                            }
                        }

                        // Instrumental / Not Found State
                        ColumnLayout {
                            visible: root.hasActiveTrack && !root.lyricsLoading && !root.lyricsFound && !root.lyricsError
                            anchors.centerIn: parent
                            spacing: 5

                            MatIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "lyrics"
                                size: 24
                                color: Theme.subtext
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Lirik belum tersedia atau instrumental"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.subtext
                            }
                        }

                        // Edge Fade Gradients Over Scrolling Lyrics (Matched to Theme.surface)
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 12
                            z: 5
                            visible: root.hasActiveTrack && !root.lyricsLoading && root.lyricsFound
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.surface }
                                GradientStop { position: 1.0; color: Qt.alpha(Theme.surface, 0.0) }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 14
                            z: 5
                            visible: root.hasActiveTrack && !root.lyricsLoading && root.lyricsFound
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.alpha(Theme.surface, 0.0) }
                                GradientStop { position: 1.0; color: Theme.surface }
                            }
                        }

                        ListView {
                            id: lyricsList
                            anchors.fill: parent
                            clip: true
                            visible: root.hasActiveTrack && !root.lyricsLoading && root.lyricsFound
                            model: root.parsedLyrics
                            boundsBehavior: Flickable.StopAtBounds

                            header: Item { width: 1; height: 10 }
                            footer: Item { width: 1; height: Math.max(72, Math.round(lyricsList.height * 0.45)) }

                            onCountChanged: {
                                if (count > 0 && Config.mediaPopoverOpen) {
                                    Qt.callLater(() => root.updateActiveLyric(true, true));
                                }
                            }

                            NumberAnimation {
                                id: lyricScrollAnim
                                target: lyricsList
                                property: "contentY"
                                duration: 280
                                easing.type: Easing.OutCubic
                            }

                            WheelHandler {
                                target: lyricsList
                                onWheel: lyricScrollAnim.stop()
                            }

                            delegate: Rectangle {
                                id: rowItem
                                required property var modelData
                                required property int index

                                readonly property bool isCurrent: index === root.activeLyricIndex
                                readonly property int dist: Math.abs(index - root.activeLyricIndex)
                                readonly property real itemSec: root.lineTime(modelData)
                                readonly property bool rowSeekable: root.player !== null && root.player.canSeek && itemSec >= 0

                                width: lyricsList.width
                                height: lyricText.implicitHeight + 6
                                color: (rowSeekable && rowHover.hovered) ? Theme.surfaceContainerLow : "transparent"

                                // Opacities kept >= 0.78 (Dark) and >= 0.85 (Light) to pass WCAG AA 4.5:1
                                opacity: isCurrent
                                    ? 1.0
                                    : (rowHover.hovered
                                        ? 1.0
                                        : (Theme.isDarkMode
                                            ? (dist === 1 ? 0.90 : (dist === 2 ? 0.84 : 0.78))
                                            : (dist === 1 ? 0.96 : (dist === 2 ? 0.90 : 0.86))))

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                                HoverHandler { id: rowHover }

                                Text {
                                    id: lyricText
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: rowItem.modelData.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: rowItem.isCurrent ? 13 : 12
                                    font.weight: rowItem.isCurrent ? Font.Bold : Font.Normal
                                    lineHeight: 1.38
                                    lineHeightMode: Text.ProportionalHeight
                                    color: rowItem.isCurrent
                                        ? Theme.text
                                        : (rowHover.hovered ? Theme.text : Theme.subtext)
                                    wrapMode: Text.Wrap

                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: rowItem.rowSeekable
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.seekToSec(rowItem.itemSec)
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------------------
                // BOTTOM-RIGHT CARD: SCRUBBER + TRANSPORT CONSOLE (454 x 88)
                // ------------------------------------------------------------
                Rectangle {
                    id: controlsCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    Layout.minimumHeight: 88
                    Layout.maximumHeight: 88
                    radius: 10
                    color: Theme.surface

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        spacing: 6

                        // Tier 1: Real Precision Scrubber + Tabular Timestamps
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            spacing: 10

                            Text {
                                Layout.minimumWidth: 32
                                text: root.formatTime(root.displayPos)
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.features: Theme.tabularFeatures
                                color: Theme.subtext
                                horizontalAlignment: Text.AlignLeft
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                id: trackScrubber
                                readonly property bool seekable: root.player !== null && root.player.canSeek && root.hasActiveTrack
                                readonly property bool interactiveHot: scrubHover.hovered || root.scrubbing || activeFocus

                                Layout.fillWidth: true
                                height: 22
                                Layout.alignment: Qt.AlignVCenter
                                activeFocusOnTab: seekable && Config.mediaPopoverOpen
                                opacity: seekable ? 1.0 : 0.45

                                Accessible.role: Accessible.Slider
                                Accessible.name: "Posisi pemutaran lagu"

                                HoverHandler { id: scrubHover }

                                Rectangle {
                                    visible: trackScrubber.activeFocus
                                    anchors.fill: parent
                                    anchors.topMargin: 2
                                    anchors.bottomMargin: 2
                                    radius: 5
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: Theme.accentInk
                                }

                                // 4px Groove Track (WCAG 1.4.11 >= 3:1 Rail Contrast + Accent Fill)
                                Rectangle {
                                    id: railTrack
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    height: 4
                                    radius: 2
                                    color: Qt.alpha(Theme.text, Theme.isDarkMode ? 0.37 : 0.52)

                                    Rectangle {
                                        width: Math.max(0, Math.min(parent.width, parent.width * root.displayRatio))
                                        height: parent.height
                                        radius: 2
                                        color: Theme.accentInk

                                        Behavior on width {
                                            enabled: !root.scrubbing
                                            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }

                                // Crisp Sora HUD Vertical Tick Marker
                                Rectangle {
                                    visible: trackScrubber.seekable
                                    width: root.scrubbing ? 5 : (trackScrubber.interactiveHot ? 4 : 3)
                                    height: trackScrubber.interactiveHot ? 14 : 11
                                    radius: width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 4 + Math.max(0, Math.min(railTrack.width, railTrack.width * root.displayRatio)) - (width / 2)
                                    color: Theme.isDarkMode ? "#FFFFFF" : Theme.text

                                    Behavior on width { NumberAnimation { duration: 90 } }
                                    Behavior on height { NumberAnimation { duration: 90 } }
                                    Behavior on x {
                                        enabled: !root.scrubbing
                                        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                    }
                                }

                                Keys.onLeftPressed: event => {
                                    if (trackScrubber.seekable) { root.seekBy(-5); event.accepted = true; }
                                }
                                Keys.onRightPressed: event => {
                                    if (trackScrubber.seekable) { root.seekBy(5); event.accepted = true; }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: trackScrubber.seekable
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    preventStealing: true

                                    function ratioAt(mx: real): real {
                                        const trackW = Math.max(1, width - 8);
                                        return Math.max(0.0, Math.min(1.0, (mx - 4) / trackW));
                                    }

                                    onPressed: mouse => {
                                        root.scrubbing = true;
                                        root.scrubRatio = ratioAt(mouse.x);
                                    }
                                    onPositionChanged: mouse => {
                                        if (pressed) root.scrubRatio = ratioAt(mouse.x);
                                    }
                                    onReleased: mouse => {
                                        const r = ratioAt(mouse.x);
                                        root.scrubbing = false;
                                        root.seekToRatio(r);
                                    }
                                    onCanceled: root.scrubbing = false
                                }
                            }

                            Text {
                                Layout.minimumWidth: 32
                                text: root.hasActiveTrack ? root.formatTime(root.len) : "0:00"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.features: Theme.tabularFeatures
                                color: Theme.subtext
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        // Tier 2: Balanced Transport & Volume Console (36px)
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36

                            // Left: Audio Mute (No Background) + Interactive Hover Volume Slider
                            Row {
                                id: volumeControl
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                readonly property bool isHovered: volAreaHover.hovered || volSliderMouse.pressed || muteHover.hovered || volSliderBox.activeFocus || muteBtn.activeFocus

                                HoverHandler {
                                    id: volAreaHover
                                }

                                WheelHandler {
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    orientation: Qt.Vertical | Qt.Horizontal
                                    onWheel: event => {
                                        const delta = Math.abs(event.angleDelta.y) > Math.abs(event.angleDelta.x)
                                            ? event.angleDelta.y
                                            : event.angleDelta.x;
                                        if (delta > 0) AudioService.changeVolume(0.05);
                                        else if (delta < 0) AudioService.changeVolume(-0.05);
                                    }
                                }

                                // 1. Mute Icon Button (Transparent background, no border)
                                Item {
                                    id: muteBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22
                                    height: 24
                                    activeFocusOnTab: AudioService.ready && Config.mediaPopoverOpen
                                    opacity: AudioService.ready ? 1.0 : 0.4

                                    Accessible.role: Accessible.Button
                                    Accessible.name: AudioService.muted ? "Bunyikan suara" : "Bisukan suara"

                                    HoverHandler { id: muteHover }

                                    MatIcon {
                                        anchors.centerIn: parent
                                        icon: AudioService.muted
                                            ? "volume_off"
                                            : (AudioService.volume > 0.5 ? "volume_up" : (AudioService.volume > 0 ? "volume_down" : "volume_mute"))
                                        size: 18
                                        color: AudioService.muted
                                            ? Theme.urgentInk
                                            : ((muteHover.hovered || volumeControl.isHovered) ? Theme.text : Theme.subtext)
                                        scale: muteMouse.pressed ? 0.90 : 1.0

                                        Behavior on scale { NumberAnimation { duration: 80 } }
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 4
                                        color: "transparent"
                                        border.width: muteBtn.activeFocus ? 1.5 : 0
                                        border.color: Theme.accentInk
                                    }

                                    MouseArea {
                                        id: muteMouse
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: AudioService.toggleMute()
                                    }

                                    Keys.onReturnPressed: AudioService.toggleMute()
                                    Keys.onSpacePressed: AudioService.toggleMute()
                                }

                                // 2. Expandable Horizontal Volume Slider (Appears on Hover, drag left-right)
                                Item {
                                    id: volSliderBox
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: volumeControl.isHovered ? 58 : 0
                                    height: 24
                                    clip: true
                                    opacity: volumeControl.isHovered ? 1.0 : 0.0
                                    activeFocusOnTab: AudioService.ready && Config.mediaPopoverOpen

                                    Accessible.role: Accessible.Slider
                                    Accessible.name: `Volume ${Math.round(AudioService.volume * 100)} persen`

                                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 140 } }

                                    // Rail groove track
                                    Rectangle {
                                        id: volTrack
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 4
                                        radius: 2
                                        color: Qt.alpha(Theme.text, Theme.isDarkMode ? 0.28 : 0.20)

                                        // Filled accent bar
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width * Math.max(0.0, Math.min(1.0, AudioService.volume))
                                            radius: 2
                                            color: AudioService.muted ? Theme.subtext : Theme.accentInk
                                        }
                                    }

                                    // Scrubber tick thumb
                                    Rectangle {
                                        width: 4
                                        height: 10
                                        radius: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Math.max(0, Math.min(volSliderBox.width - width, (volSliderBox.width * Math.max(0.0, Math.min(1.0, AudioService.volume))) - (width / 2)))
                                        color: Theme.isDarkMode ? "#FFFFFF" : Theme.text
                                        visible: volSliderBox.width > 14
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 4
                                        color: "transparent"
                                        border.width: volSliderBox.activeFocus ? 1.5 : 0
                                        border.color: Theme.accentInk
                                    }

                                    Keys.onLeftPressed: event => {
                                        AudioService.changeVolume(-0.05);
                                        event.accepted = true;
                                    }
                                    Keys.onRightPressed: event => {
                                        AudioService.changeVolume(0.05);
                                        event.accepted = true;
                                    }

                                    MouseArea {
                                        id: volSliderMouse
                                        anchors.fill: parent
                                        anchors.topMargin: -6
                                        anchors.bottomMargin: -6
                                        cursorShape: Qt.PointingHandCursor
                                        preventStealing: true

                                        function updateFromPos(mx: real): void {
                                            if (volSliderBox.width <= 0) return;
                                            const r = Math.max(0.0, Math.min(1.0, mx / volSliderBox.width));
                                            AudioService.setVolume(r);
                                        }

                                        onPressed: mouse => updateFromPos(mouse.x)
                                        onPositionChanged: mouse => {
                                            if (pressed) updateFromPos(mouse.x);
                                        }
                                    }
                                }

                                // 3. Volume text indicator (Percentage / Mati)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: AudioService.muted ? "Mati" : `${Math.round(AudioService.volume * 100)}%`
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    font.features: Theme.tabularFeatures
                                    color: AudioService.muted ? Theme.urgentInk : Theme.subtext
                                }
                            }

                            // Center: Shuffle | Prev | Play/Pause Focal | Next | Repeat
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                BentoIconBtn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 28
                                    iconSize: 15
                                    icon: "shuffle"
                                    active: root.shuffleActive
                                    btnEnabled: root.player !== null && root.player.shuffleSupported
                                    accessName: root.shuffleActive ? "Matikan acak" : "Aktifkan acak"
                                    onTriggered: {
                                        if (root.player?.shuffleSupported) root.player.shuffle = !root.player.shuffle;
                                    }
                                }

                                BentoIconBtn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    btnRadius: 8
                                    iconSize: 18
                                    icon: "skip_previous"
                                    btnEnabled: root.player?.canGoPrevious ?? false
                                    accessName: "Lagu sebelumnya"
                                    onTriggered: if (root.player?.canGoPrevious) root.player.previous()
                                }

                                BentoIconBtn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 36
                                    btnRadius: 18
                                    iconSize: 20
                                    iconFill: 1.0
                                    focal: true
                                    icon: root.isPlaying ? "pause" : "play_arrow"
                                    btnEnabled: root.player?.canTogglePlaying ?? false
                                    accessName: root.isPlaying ? "Jeda pemutaran" : "Putar lagu"
                                    onTriggered: if (root.player?.canTogglePlaying) root.player.togglePlaying()
                                }

                                BentoIconBtn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 30
                                    btnRadius: 8
                                    iconSize: 18
                                    icon: "skip_next"
                                    btnEnabled: root.player?.canGoNext ?? false
                                    accessName: "Lagu berikutnya"
                                    onTriggered: if (root.player?.canGoNext) root.player.next()
                                }

                                BentoIconBtn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 28
                                    iconSize: 15
                                    icon: root.loopMode === MprisLoopState.Track ? "repeat_one" : "repeat"
                                    active: root.repeatActive
                                    btnEnabled: root.player !== null && root.player.loopSupported
                                    accessName: root.loopMode === MprisLoopState.None
                                        ? "Aktifkan ulang daftar"
                                        : (root.loopMode === MprisLoopState.Playlist ? "Ulangi satu lagu" : "Matikan ulang")
                                    onTriggered: root.cycleLoopState()
                                }
                            }

                            // Right: Quick Seek -10s / +10s
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                BentoIconBtn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 28
                                    iconSize: 16
                                    icon: "replay_10"
                                    btnEnabled: root.player !== null && root.player.canSeek && root.hasActiveTrack
                                    accessName: "Mundur 10 detik"
                                    onTriggered: root.seekBy(-10)
                                }

                                BentoIconBtn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 28
                                    iconSize: 16
                                    icon: "forward_10"
                                    btnEnabled: root.player !== null && root.player.canSeek && root.hasActiveTrack
                                    accessName: "Maju 10 detik"
                                    onTriggered: root.seekBy(10)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
