import QtQuick
import Quickshell

PopupWindow {
    id: root

    property Item target: null
    property string text: ""
    property bool hovered: false

    visible: false
    color: "transparent"

    mask: Region {
        width: 0
        height: 0
    }

    implicitWidth: label.implicitWidth + 24
    implicitHeight: label.implicitHeight + 14

    anchor.item: target
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.All

    function scheduleAnchorUpdate() {
        if (visible)
            anchorUpdateTimer.restart();
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.bubbleRadius
        color: Theme.mantle
        border.color: Theme.bubbleBorder
        border.width: 1

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }

    Timer {
        id: anchorUpdateTimer
        interval: 0
        onTriggered: {
            if (root.visible)
                root.anchor.updateAnchor();
        }
    }

    Connections {
        target: root.target

        function onXChanged() {
            root.scheduleAnchorUpdate();
        }
        function onYChanged() {
            root.scheduleAnchorUpdate();
        }
        function onWidthChanged() {
            root.scheduleAnchorUpdate();
        }
        function onHeightChanged() {
            root.scheduleAnchorUpdate();
        }
    }

    Timer {
        id: showTimer
        interval: Theme.tooltipDelay
        onTriggered: {
            if (root.hovered && root.text.length > 0)
                root.visible = true;
        }
    }

    onHoveredChanged: {
        if (root.hovered)
            showTimer.restart();
        else {
            showTimer.stop();
            root.visible = false;
        }
    }

    onTextChanged: {
        if (root.hovered)
            showTimer.restart();
    }

    onTargetChanged: {
        showTimer.stop();
        root.visible = false;
    }
}
