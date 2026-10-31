import QtQuick
import org.kde.plasma.private.volume

// Output volume and the device lists, on plasma-pa's live PulseAudio/PipeWire
// objects. The slider can move the volume while it is being dragged, which
// the pactl version could not do without spawning a process per motion event.
Item {
    id: audio
    visible: false

    // What Plasma itself treats as "the" output; null for a moment at startup
    // until the sound server has reported its default.
    readonly property var sink: PreferredDevice.sink
    readonly property bool available: sink !== null
    readonly property real volume: sink ? sink.volume / PulseAudio.NormalVolume : 0
    readonly property bool muted: sink ? sink.muted : false

    readonly property string icon: {
        if (!sink || muted || volume <= 0) {
            return "audio-volume-muted-symbolic";
        }
        if (volume < 0.34) {
            return "audio-volume-low-symbolic";
        }
        return volume < 0.67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic";
    }

    readonly property alias outputs: sinks
    readonly property alias inputs: sources

    /**
     * @param {real} fraction - 0 to 1 of normal (100%) volume.
     */
    function setVolume(fraction) {
        if (!sink) {
            return;
        }
        const clamped = Math.max(0, Math.min(1, fraction));
        if (sink.muted && clamped > 0) {
            sink.muted = false;
        }
        sink.volume = Math.round(clamped * PulseAudio.NormalVolume);
    }

    function toggleMute() {
        if (sink) {
            sink.muted = !sink.muted;
        }
    }

    /**
     * @param {object} device - A row's PulseObject.
     */
    function makeDefault(device) {
        device.default = true;
    }

    SinkModel { id: sinkModel }
    SourceModel { id: sourceModel }

    // Drops the "auto_null" dummy output and ports with nothing plugged in.
    PulseObjectFilterModel {
        id: sinks
        sourceModel: sinkModel
        filterOutInactiveDevices: true
    }
    PulseObjectFilterModel {
        id: sources
        sourceModel: sourceModel
        filterOutInactiveDevices: true
    }
}
