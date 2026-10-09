import QtQuick
import Quickshell
import ".." as Shell
import "../primitives" as Primitives

PopupWindow {
    id: root

    required property Item target
    required property date today

    readonly property var locale: Qt.locale()
    readonly property date monthStart: new Date(today.getFullYear(), today.getMonth(), 1)
    readonly property int firstDayOffset: (monthStart.getDay() + 7 - locale.firstDayOfWeek) % 7
    readonly property int daysInMonth: new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()
    readonly property int cellSize: 32

    visible: false
    color: "transparent"
    implicitWidth: cellSize * 7 + 24
    implicitHeight: content.implicitHeight + 24

    mask: Region {
        width: 0
        height: 0
    }

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
        radius: Shell.Theme.bubbleRadius
        color: Shell.Theme.mantle
        border.color: Shell.Theme.bubbleBorder
        border.width: 1

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 8

            Primitives.ThemeText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.today, "MMMM yyyy")
                color: Shell.Theme.text
            }

            Row {
                Repeater {
                    model: 7

                    delegate: Primitives.ThemeText {
                        required property int index

                        width: root.cellSize
                        height: root.cellSize
                        text: root.locale.dayName((root.locale.firstDayOfWeek + index - 1) % 7 + 1, Locale.ShortFormat)
                        color: Shell.Theme.subtext0
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Grid {
                columns: 7

                Repeater {
                    model: Math.ceil((root.firstDayOffset + root.daysInMonth) / 7) * 7

                    delegate: Rectangle {
                        required property int index
                        readonly property int day: index - root.firstDayOffset + 1
                        readonly property bool inMonth: day > 0 && day <= root.daysInMonth
                        readonly property bool isToday: inMonth && day === root.today.getDate()

                        width: root.cellSize
                        height: root.cellSize
                        radius: Shell.Theme.bubbleRadius
                        color: isToday ? Shell.Theme.lavender : "transparent"

                        Primitives.ThemeText {
                            anchors.centerIn: parent
                            text: parent.inMonth ? parent.day : ""
                            color: parent.isToday ? Shell.Theme.mantle : Shell.Theme.text
                        }
                    }
                }
            }
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
}
