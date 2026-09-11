import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    implicitWidth: trayRow.implicitWidth + Shell.Theme.bubblePadding * 2
    implicitHeight: Shell.Theme.widgetHeight
    property var hoveredItem: null
    property bool itemHovered: false
    Primitives.Bubble {
        id: bubble
        anchors.fill: parent
        hovered: hoverHandler.hovered
    }

    HoverHandler {
        id: hoverHandler
    }

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayItem
                required property var modelData

                width: Shell.Theme.widgetHeight
                height: Shell.Theme.widgetHeight

                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: trayItem.modelData.icon
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    hoverEnabled: true
                    onEntered: {
                        root.hoveredItem = trayItem.modelData;
                        root.itemHovered = true;
                    }
                    onExited: root.itemHovered = false
                    onClicked: function (mouse) {
                        const point = root.QsWindow.itemPosition(trayItem);
                        if (mouse.button === Qt.LeftButton) {
                            if (trayItem.modelData.onlyMenu)
                                trayItem.modelData.display(root.QsWindow.window, point.x, point.y + trayItem.height);
                            else
                                trayItem.modelData.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            trayItem.modelData.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton && trayItem.modelData.hasMenu) {
                            trayItem.modelData.display(root.QsWindow.window, point.x, point.y + trayItem.height);
                        }
                    }
                    onWheel: function (wheel) {
                        trayItem.modelData.scroll(wheel.angleDelta.y, false);
                        wheel.accepted = true;
                    }
                }
            }
        }
    }
    Shell.BarTooltip {
        target: bubble
        text: root.hoveredItem ? (root.hoveredItem.tooltipTitle + (root.hoveredItem.tooltipDescription ? "\n" + root.hoveredItem.tooltipDescription : "")) : ""
        hovered: root.itemHovered
    }
}
