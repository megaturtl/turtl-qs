import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    implicitWidth: label.implicitWidth + Shell.Theme.bubblePadding * 2
    implicitHeight: Shell.Theme.widgetHeight

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink?.audio
    readonly property real volume: audio?.volume ?? 0
    readonly property bool muted: audio?.muted ?? false
    readonly property string description: sink?.description || sink?.name || "No audio device"

    function setVolume(value) {
        if (sink?.ready && audio)
            audio.volume = Math.max(0, Math.min(1, value));
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    Primitives.WidgetShell {
        anchors.fill: parent
        hovered: mouse.containsMouse
        tooltipTarget: mouse
        tooltipText: ["Device: " + root.description, "Muted: " + (root.muted ? "yes" : "no"), "────────────────", "Left · open mixer", "Right · toggle mute", "Scroll · adjust volume"].join("\n")

        Primitives.ThemeText {
            id: label
            anchors.centerIn: parent
            text: Shell.Theme.volumeIcon(root.volume, root.muted) + " " + Math.round(root.volume * 100) + "%"
            color: root.muted ? Shell.Theme.overlay0 : Shell.Theme.sky
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (event) {
                if (event.button === Qt.LeftButton)
                    Quickshell.execDetached(["pwvucontrol"]);
                else if (event.button === Qt.RightButton && root.sink?.ready && root.audio)
                    root.audio.muted = !root.audio.muted;
            }
            onWheel: function (wheel) {
                if (wheel.angleDelta.y !== 0)
                    root.setVolume(root.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05));
            }
        }
    }
}
