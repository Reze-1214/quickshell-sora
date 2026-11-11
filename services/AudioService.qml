pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool ready: !!sink?.ready && !!sink?.audio
    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: {
        const v = sink?.audio?.volume ?? 0;
        return isNaN(v) ? 0 : Math.max(0.0, Math.min(1.5, v));
    }

    function setVolume(newVol: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0.0, Math.min(1.0, newVol));
        }
    }

    function changeVolume(delta: real): void {
        setVolume(volume + delta);
    }

    function toggleMute(): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = !sink.audio.muted;
        }
    }

    // Microphone Input Node (Source)
    readonly property bool micReady: !!source?.ready && !!source?.audio
    readonly property bool micMuted: !!source?.audio?.muted
    readonly property real micVolume: {
        const v = source?.audio?.volume ?? 0;
        return isNaN(v) ? 0 : Math.max(0.0, Math.min(1.5, v));
    }

    function setMicVolume(newVol: real): void {
        const target = Math.max(0.0, Math.min(1.0, newVol));
        if (source?.ready && source?.audio) {
            source.audio.muted = false;
            source.audio.volume = target;
        }
    }

    function changeMicVolume(delta: real): void {
        setMicVolume(micVolume + delta);
    }

    function toggleMicMute(): void {
        if (source?.ready && source?.audio) {
            source.audio.muted = !source.audio.muted;
        }
    }

    // Critical: Bind default sink and source to PipeWire registry
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n !== null && n !== undefined)
    }
}
