import QtQuick
import ".." as Shell

Item {
    id: root

    property bool hovered: false
    property Item tooltipTarget: null
    property string tooltipText: ""
    property alias bubble: bubbleItem
    default property alias content: bubbleItem.data

    Bubble {
        id: bubbleItem
        anchors.fill: parent
        hovered: root.hovered
    }

    Shell.BarTooltip {
        target: root.tooltipTarget
        text: root.tooltipText
        hovered: root.hovered
    }
}
