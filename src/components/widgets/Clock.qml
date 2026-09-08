import QtQuick
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    implicitWidth: clockText.implicitWidth + Shell.Theme.bubblePadding * 2
    implicitHeight: Shell.Theme.widgetHeight

    property string shortTime: ""
    property string longTime: ""

    function updateTime() {
        const now = new Date();
        shortTime = Qt.formatDateTime(now, "HH:mm · ddd MMM dd");
        longTime = Qt.formatDateTime(now, "HH:mm:ss · ddd MMM dd");
    }
    Primitives.WidgetShell {
        anchors.fill: parent
        hovered: mouse.containsMouse
        tooltipTarget: mouse
        tooltipText: root.longTime

        Primitives.ThemeText {
            id: clockText
            anchors.centerIn: parent
            text: root.shortTime
            color: Shell.Theme.lavender
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    Timer {
        interval: Shell.Theme.clockInterval
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.updateTime()
    }
}
