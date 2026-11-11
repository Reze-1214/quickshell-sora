import QtQuick
import Quickshell
import Quickshell.Wayland
import "../config"

PanelWindow {
    id: root

    WlrLayershell.namespace: "sora-background"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: Config.enableBackgroundLayer && Config.wallpaperPath.length > 0
    color: Theme.background

    readonly property int targetW: (root.screen && root.screen.width > 0) ? root.screen.width : (root.width > 0 ? root.width : 1366)
    readonly property int targetH: (root.screen && root.screen.height > 0) ? root.screen.height : (root.height > 0 ? root.height : 768)

    readonly property string targetWallpaperUrl: (Config.wallpaperPath && Config.wallpaperPath.length > 0)
        ? (Config.wallpaperPath.startsWith("file://")
            ? Config.wallpaperPath
            : `file://${Config.wallpaperPath.replace(/%/g, "%25").replace(/#/g, "%23").replace(/\?/g, "%3F")}`)
        : ""

    property string settledSource: ""
    property string oldSource: ""
    property string newSource: ""
    property bool transitioning: false
    property real transitionProgress: 0.0

    function syncWallpaperTarget(): void {
        const nextUrl = root.targetWallpaperUrl;
        if (nextUrl.length === 0) return;

        // Initial boot / not yet rendered: load straight into baseImage without wipe
        if (root.settledSource.length === 0 || baseImage.status !== Image.Ready) {
            root.settledSource = nextUrl;
            return;
        }

        if (nextUrl === root.settledSource && !root.transitioning) return;

        // If already transitioning, promote ready incoming image as the new base before chaining
        if (root.transitioning) {
            transitionAnim.stop();
            if (newImage.status === Image.Ready && root.newSource.length > 0) {
                root.settledSource = root.newSource;
            }
        }

        if (nextUrl === root.settledSource) {
            root.transitioning = false;
            root.oldSource = "";
            root.newSource = "";
            root.transitionProgress = 0.0;
            return;
        }

        root.oldSource = root.settledSource;
        root.newSource = nextUrl;
        root.transitionProgress = 0.0;
        root.transitioning = true;
        maybeStartTransition();
    }

    function maybeStartTransition(): void {
        if (!root.transitioning) return;
        if (oldImage.status === Image.Ready && newImage.status === Image.Ready && !transitionAnim.running) {
            transitionAnim.restart();
        }
    }

    function finishTransitionIfReady(): void {
        if (!root.transitioning || transitionAnim.running) return;
        if (baseImage.status === Image.Ready && root.settledSource === root.newSource) {
            root.transitioning = false;
            root.oldSource = "";
            root.newSource = "";
            root.transitionProgress = 0.0;
        }
    }

    onTargetWallpaperUrlChanged: syncWallpaperTarget()
    Component.onCompleted: syncWallpaperTarget()

    Image {
        id: baseImage
        z: 0
        anchors.fill: parent
        source: root.settledSource
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.targetW
        sourceSize.height: root.targetH
        asynchronous: true
        smooth: true
        mipmap: true
        cache: true
        opacity: status === Image.Ready ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        onStatusChanged: root.finishTransitionIfReady()
    }

    Image {
        id: oldImage
        anchors.fill: parent
        visible: root.transitioning
        source: root.oldSource
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.targetW
        sourceSize.height: root.targetH
        asynchronous: true
        smooth: true
        mipmap: true
        cache: true
        onStatusChanged: {
            if (status === Image.Error) {
                root.transitioning = false;
                root.oldSource = "";
                root.newSource = "";
                root.transitionProgress = 0.0;
            } else {
                root.maybeStartTransition();
            }
        }
    }

    Image {
        id: newImage
        anchors.fill: parent
        visible: root.transitioning
        source: root.newSource
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.targetW
        sourceSize.height: root.targetH
        asynchronous: true
        smooth: true
        mipmap: true
        cache: true
        onStatusChanged: {
            if (status === Image.Error) {
                root.transitioning = false;
                root.oldSource = "";
                root.newSource = "";
                root.transitionProgress = 0.0;
            } else {
                root.maybeStartTransition();
            }
        }
    }

    ShaderEffectSource {
        id: oldTexSource
        sourceItem: oldImage
        hideSource: true
        live: root.transitioning
    }

    ShaderEffectSource {
        id: newTexSource
        sourceItem: newImage
        hideSource: true
        live: root.transitioning
    }

    // Radial bloom transition between old and new wallpaper without blocking idle performance
    ShaderEffect {
        id: transitionShader
        z: 1
        anchors.fill: parent
        visible: root.transitioning && oldImage.status === Image.Ready && newImage.status === Image.Ready
        property var oldTex: oldTexSource
        property var newTex: newTexSource
        property real progress: root.transitionProgress
        property real aspect: height > 0 ? (width / height) : 1.0
        property real centerX: 0.5
        property real centerY: 0.5
        fragmentShader: Qt.resolvedUrl("../shaders/wallpaper_transition.frag.qsb")
    }

    NumberAnimation {
        id: transitionAnim
        target: root
        property: "transitionProgress"
        from: 0.0
        to: 1.0
        duration: 720
        easing.type: Easing.OutCubic
        onFinished: {
            root.settledSource = root.newSource;
            root.finishTransitionIfReady();
        }
    }

    // Desktop Click Catcher for Context Menu
    MouseArea {
        z: 2
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Config.openDesktopContextMenu(mouse.x, mouse.y);
            } else {
                Config.closeDesktopContextMenu();
            }
        }
    }

    // Aesthetic Harmonized Desktop Widgets (Image 1 + 2 + 3 fusion)
    DesktopWidgets {
        id: desktopWidgets
        z: 3
    }
}
