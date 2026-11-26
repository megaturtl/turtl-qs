import QtQuick
import Quickshell
import Quickshell.Io
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    implicitWidth: content.implicitWidth + Shell.Theme.bubblePadding * 2
    implicitHeight: Shell.Theme.widgetHeight
    Primitives.Bubble {
        anchors.fill: parent
        hovered: mouse.containsMouse
    }

    property var snapshot: null

    function consumeSnapshot(line) {
        try {
            const next = JSON.parse(line);
            if (Number.isSafeInteger(next?.count) && next.count >= 0 && typeof next.dnd === "boolean")
                snapshot = next;
        } catch (_) {
            // Keep the last complete snapshot while the stream is open.
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Primitives.ThemeText {
            text: root.snapshot?.dnd ? "󰂛" : root.snapshot?.count > 0 ? "󰂚" : "󰂜"
            color: root.snapshot && !root.snapshot.dnd ? Shell.Theme.yellow : Shell.Theme.overlay0
        }

        Primitives.ThemeText {
            text: root.snapshot?.count ?? "–"
            color: root.snapshot && !root.snapshot.dnd ? Shell.Theme.yellow : Shell.Theme.overlay0
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        onClicked: function (mouse) {
            if (!root.snapshot)
                return;
            if (mouse.button === Qt.LeftButton)
                Quickshell.execDetached(["swaync-client", "-t", "-sw"]);
            else if (mouse.button === Qt.RightButton)
                Quickshell.execDetached(["swaync-client", "-C", "-sw"]);
        }
    }
    Shell.BarTooltip {
        target: mouse
        text: root.snapshot ? root.snapshot.count + " notification" + (root.snapshot.count === 1 ? "" : "s") + "\nDo Not Disturb: " + (root.snapshot.dnd ? "on" : "off") + "\n────────────────\nLeft · toggle panel\nRight · clear all" : "Waiting for notification state"
        hovered: mouse.containsMouse
    }

    Process {
        id: subscription
        running: true
        command: ["swaync-client", "--subscribe"]
        stdout: SplitParser {
            onRead: line => root.consumeSnapshot(line)
        }
        onRunningChanged: {
            if (!running) {
                root.snapshot = null;
                reconnect.restart();
            }
        }
    }

    Timer {
        id: reconnect
        interval: Shell.Theme.notificationReconnectDelay
        onTriggered: subscription.running = true
    }
}
