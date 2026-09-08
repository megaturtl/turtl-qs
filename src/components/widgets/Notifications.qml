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

    property int count: 0
    property bool doNotDisturb: false
    property bool refreshPending: false
    property int refreshesRunning: 0

    function refresh() {
        if (refreshesRunning > 0) {
            refreshPending = true;
            return;
        }

        refreshPending = false;
        refreshesRunning = 2;
        countProcess.running = true;
        dndProcess.running = true;
    }

    function completeRefresh() {
        refreshesRunning -= 1;
        if (refreshesRunning === 0 && refreshPending)
            refresh();
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Primitives.ThemeText {
            text: root.doNotDisturb ? "󰂛" : root.count > 0 ? "󰂚" : "󰂜"
            color: root.doNotDisturb ? Shell.Theme.overlay0 : Shell.Theme.yellow
        }

        Primitives.ThemeText {
            text: root.count
            color: root.doNotDisturb ? Shell.Theme.overlay0 : Shell.Theme.yellow
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        onClicked: function (mouse) {
            if (mouse.button === Qt.LeftButton)
                Quickshell.execDetached(["swaync-client", "-t", "-sw"]);
            else if (mouse.button === Qt.RightButton)
                Quickshell.execDetached(["swaync-client", "-C"]);
        }
    }
    Shell.BarTooltip {
        target: mouse
        text: root.count + " notification" + (root.count === 1 ? "" : "s") + "\nDo Not Disturb: " + (root.doNotDisturb ? "on" : "off") + "\n────────────────\nLeft · toggle panel\nRight · clear all"
        hovered: mouse.containsMouse
    }

    Process {
        id: countProcess
        command: ["swaync-client", "-c"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.count = Number(text.trim()) || 0;
                root.completeRefresh();
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: dndProcess
        command: ["swaync-client", "-D"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.doNotDisturb = text.trim() === "true";
                root.completeRefresh();
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: subscription
        running: true
        command: ["swaync-client", "--subscribe"]
        stdout: SplitParser {
            onRead: root.refresh()
        }
        stderr: StdioCollector {}
        onExited: reconnect.start()
    }

    Timer {
        id: reconnect
        interval: Shell.Theme.notificationReconnectDelay
        onTriggered: subscription.running = true
    }

    Component.onCompleted: refresh()
}
