import QtQuick
import Quickshell
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    implicitWidth: label.implicitWidth + Shell.Theme.bubblePadding * 2
    implicitHeight: Shell.Theme.widgetHeight

    Primitives.WidgetShell {
        anchors.fill: parent
        hovered: mouse.containsMouse
        tooltipTarget: mouse
        tooltipText: "Left · power menu (wlogout)\nRight · lock screen (hyprlock)"

        Primitives.ThemeText {
            id: label
            anchors.centerIn: parent
            text: "󰐥"
            color: Shell.Theme.red
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (event) {
                if (event.button === Qt.LeftButton)
                    Quickshell.execDetached(["wlogout"]);
                else if (event.button === Qt.RightButton)
                    Quickshell.execDetached(["hyprlock"]);
            }
        }
    }
}
