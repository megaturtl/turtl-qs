import QtQuick
import "widgets" as Widgets

Item {
    id: root

    implicitHeight: Theme.barHeight

    Row {
        id: startWidgets
        anchors.left: parent.left
        anchors.leftMargin: Theme.barPaddingX
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.widgetSpacing

        Widgets.Workspaces {}
        Widgets.Mpris {}
    }

    Row {
        id: centerWidgets
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.widgetSpacing

        Widgets.Notifications {}
        Widgets.Clock {}
        Widgets.Tray {}
    }

    Row {
        id: endWidgets
        anchors.right: parent.right
        anchors.rightMargin: Theme.barPaddingX
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.widgetSpacing

        Widgets.Hardware {}
        Widgets.Battery {}
        Widgets.Network {}
        Widgets.Audio {}
        Widgets.Power {}
    }
}
