import QtQuick
import ".." as Shell

Rectangle {
    id: root

    property bool hovered: false
    property color background: Shell.Theme.bubbleBackground
    property color accent: Shell.Theme.bubbleHover

    radius: Shell.Theme.bubbleRadius
    color: hovered ? accent : background
    border.color: Shell.Theme.bubbleBorder
    border.width: 1

    Behavior on color {
        ColorAnimation {
            duration: Shell.Theme.bubbleHoverDuration
        }
    }
}
