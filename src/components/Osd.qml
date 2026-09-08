import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    property var sharedState: null
    readonly property bool isStateOwner: sharedState === null
    readonly property var stateOwner: sharedState || root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property bool displayVisible: stateOwner.osdVisible
    readonly property string displayKind: stateOwner.osdKind
    readonly property real displayValue: stateOwner.osdValue
    readonly property bool displayMuted: stateOwner.osdMuted

    property bool osdVisible: false
    property string osdKind: "volume"
    property real osdValue: 0
    property bool osdMuted: false
    property bool startupReady: false
    property bool brightnessKnown: false
    property real brightnessValue: 0
    property string backlightPath: ""

    implicitWidth: bubble.implicitWidth
    implicitHeight: bubble.implicitHeight
    visible: displayVisible

    function clamp(value) {
        return Math.max(0, Math.min(1, Number(value) || 0));
    }

    function present(kind, value, muted) {
        if (!isStateOwner)
            return;
        osdKind = kind;
        osdValue = clamp(value);
        osdMuted = muted;
        if (!startupReady)
            return;
        osdVisible = true;
        hideTimer.restart();
    }

    function showVolume() {
        if (!isStateOwner || !sinkAudio)
            return;
        present("volume", sinkAudio.volume, sinkAudio.muted);
    }

    function handleBrightness(valueText, maximumText) {
        if (!isStateOwner)
            return;
        const maximum = Number(maximumText.trim());
        const value = Number(valueText.trim());
        if (!isFinite(value) || !isFinite(maximum) || maximum <= 0)
            return;
        const normalizedValue = value / maximum;
        if (!brightnessKnown) {
            brightnessKnown = true;
            brightnessValue = clamp(normalizedValue);
            return;
        }

        if (Math.abs(normalizedValue - brightnessValue) > 0.0001)
            present("brightness", normalizedValue, false);
        brightnessValue = clamp(normalizedValue);
    }

    Timer {
        id: startupGrace
        interval: Theme.osdStartupDelay
        running: root.isStateOwner
        repeat: false
        onTriggered: root.startupReady = true
    }

    Timer {
        id: hideTimer
        interval: Theme.osdTimeout
        repeat: false
        onTriggered: root.osdVisible = false
    }

    PwObjectTracker {
        objects: root.isStateOwner ? [root.sink] : []
    }

    Connections {
        target: root.isStateOwner ? root.sinkAudio : null

        function onVolumeChanged() {
            root.showVolume();
        }

        function onMutedChanged() {
            root.showVolume();
        }
    }

    FolderListModel {
        id: backlightDevices
        folder: root.isStateOwner ? "file:///sys/class/backlight" : ""
        showFiles: false

        onCountChanged: {
            if (count === 0) {
                root.backlightPath = "";
                root.brightnessKnown = false;
                return;
            }

            root.backlightPath = backlightDevices.get(0, "filePath");
        }
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

    Rectangle {
        id: bubble
        anchors.centerIn: parent
        implicitWidth: contentRow.implicitWidth + 36
        implicitHeight: 56
        radius: 14
        color: Theme.withAlpha(Theme.base, 0.55)
        opacity: root.displayVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 14

            Text {
                width: 22
                text: root.displayKind === "volume" ? Theme.volumeIcon(root.displayValue, root.displayMuted) : Theme.brightnessIcon(root.displayValue)
                color: root.displayKind === "brightness" ? Theme.yellow : root.displayMuted ? Theme.overlay0 : Theme.sky
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                width: 140
                height: 4
                anchors.verticalCenter: parent.verticalCenter
                radius: height / 2
                color: Theme.withAlpha(Theme.overlay0, 0.35)

                Rectangle {
                    width: parent.width * root.displayValue
                    height: parent.height
                    radius: height / 2
                    color: root.displayKind === "brightness" ? Theme.yellow : root.displayMuted ? Theme.overlay0 : Theme.sky
                }
            }

            Text {
                width: 52
                text: root.displayKind === "volume" && root.displayMuted ? "muted" : `${Math.round(root.displayValue * 100)}%`
                color: root.displayKind === "volume" && root.displayMuted ? Theme.overlay0 : Theme.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
