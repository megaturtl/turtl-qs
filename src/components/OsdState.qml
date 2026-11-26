import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Scope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink?.audio ?? null
    property bool osdVisible: false
    property string osdKind: "volume"
    property real osdValue: 0
    property bool osdMuted: false
    property bool startupReady: false
    property real brightnessValue: -1
    property string backlightPath: ""

    onBacklightPathChanged: brightnessValue = -1

    function clamp(value) {
        return Math.max(0, Math.min(1, Number(value) || 0));
    }

    function present(kind, value, muted) {
        osdKind = kind;
        osdValue = clamp(value);
        osdMuted = muted;
        if (startupReady) {
            osdVisible = true;
            hideTimer.restart();
        }
    }

    function showVolume() {
        if (sinkAudio)
            present("volume", sinkAudio.volume, sinkAudio.muted);
    }

    function handleBrightness(valueText, maximumText) {
        if (!valueText.trim() || !maximumText.trim())
            return;
        const maximum = Number(maximumText);
        const value = Number(valueText);
        if (!Number.isFinite(value) || !Number.isFinite(maximum) || maximum <= 0)
            return;
        const normalized = clamp(value / maximum);
        if (brightnessValue >= 0 && Math.abs(normalized - brightnessValue) > 0.0001)
            present("brightness", normalized, false);
        brightnessValue = normalized;
    }

    Timer {
        interval: 800
        running: true
        onTriggered: root.startupReady = true
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.osdVisible = false
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Connections {
        target: root.sinkAudio

        function onVolumeChanged() {
            root.showVolume();
        }

        function onMutedChanged() {
            root.showVolume();
        }
    }

    FolderListModel {
        id: backlightDevices
        folder: "file:///sys/class/backlight"
        showFiles: false
        onCountChanged: root.backlightPath = count > 0 ? get(0, "filePath") : ""
    }

    FileView {
        id: brightnessFile
        path: root.backlightPath ? `${root.backlightPath}/brightness` : ""
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: root.handleBrightness(text(), maximumBrightnessFile.text())
    }

    FileView {
        id: maximumBrightnessFile
        path: root.backlightPath ? `${root.backlightPath}/max_brightness` : ""
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: root.handleBrightness(brightnessFile.text(), text())
    }
}
