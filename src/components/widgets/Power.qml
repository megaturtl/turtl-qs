import QtQuick
import Quickshell
import Quickshell.Io
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    readonly property bool menuAvailable: Shell.SessionTools.has("wlogout")
    readonly property bool lockerAvailable: Shell.SessionTools.has("hyprlock")
    property bool lockFailed: false

    function requestLock() {
        if (!lockerAvailable)
            return;
        lockFailed = false;
        // The locker must outlive a Quickshell reload or monitor removal.
        Quickshell.execDetached(["sh", "-c", "hyprlock || quickshell ipc --pid \"$1\" call power reportLockFailure || exec notify-send -u critical 'Screen locker failed' 'Lock not confirmed.'", "sh", String(Quickshell.processId)]);
    }

    IpcHandler {
        target: "power"

        function reportLockFailure(): void {
            root.lockFailed = true;
        }
    }

    visible: menuAvailable || lockerAvailable
    implicitWidth: visible ? label.implicitWidth + Shell.Theme.bubblePadding * 2 : 0
    implicitHeight: Shell.Theme.widgetHeight

    Primitives.WidgetShell {
        anchors.fill: parent
        hovered: mouse.containsMouse
        tooltipTarget: mouse
        tooltipText: [root.menuAvailable ? "Left · power menu (wlogout)" : "Power menu unavailable", root.lockFailed ? "Screen locker failed · lock not confirmed\nRight · retry" : root.lockerAvailable ? "Right · lock screen (hyprlock)" : "Screen locker unavailable"].join("\n")

        Primitives.ThemeText {
            id: label
            anchors.centerIn: parent
            text: root.lockFailed ? "󰀪" : "󰐥"
            color: Shell.Theme.red
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (event) {
                if (event.button === Qt.LeftButton && root.menuAvailable)
                    Quickshell.execDetached(["wlogout"]);
                else if (event.button === Qt.RightButton)
                    root.requestLock();
            }
        }
    }
}
