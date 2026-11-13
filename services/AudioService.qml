pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property var sinks: {
        const all = Pipewire.nodes?.values ?? [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n && !n.isStream && n.isSink && n.audio !== null) {
                out.push(n);
            }
        }
        return out;
    }

    readonly property var sources: {
        const all = Pipewire.nodes?.values ?? [];
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const n = all[i];
            if (n && !n.isStream && !n.isSink && n.audio !== null && !String(n.name ?? "").endsWith(".monitor")) {
                out.push(n);
            }
        }
        return out;
    }

    function nodeLabel(node: var): string {
        if (!node) return "Audio Device";
        const nick = (node.nickname ?? "").trim();
        if (nick.length > 0) return nick;
        const desc = (node.description ?? "").trim();
        if (desc.length > 0) return desc;
        return node.name ?? "Audio Device";
    }

    function setDefaultSink(node: var): void {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node: var): void {
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }

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

    // Critical: Bind default sink, source, and device list to PipeWire registry
    PwObjectTracker {
        objects: {
            const list = [root.sink, root.source];
            for (let i = 0; i < root.sinks.length; i++) list.push(root.sinks[i]);
            for (let i = 0; i < root.sources.length; i++) list.push(root.sources[i]);
            return list.filter(n => n !== null && n !== undefined);
        }
    }
}
