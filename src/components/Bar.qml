import QtQuick
import "widgets" as Widgets

Item {
    id: root

    implicitHeight: Theme.barHeight
    readonly property real leftEdge: Theme.barPaddingX
    readonly property real rightEdge: Math.max(leftEdge, width - Theme.barPaddingX)
    readonly property real gap: Theme.widgetSpacing
    readonly property real space: Math.max(0, rightEdge - leftEdge - 2 * gap)
    readonly property real startReserve: Math.min(startWidgets.idealWidth, space / 4)

    component WidgetStrip: Flickable {
        default property alias widgets: row.data
        readonly property real idealWidth: row.implicitWidth

        anchors.verticalCenter: parent.verticalCenter
        height: Theme.widgetHeight
        contentWidth: idealWidth
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        interactive: contentWidth > width
        clip: true

        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.widgetSpacing
        }
    }

    WidgetStrip {
        id: startWidgets
        x: root.leftEdge
        width: Math.min(idealWidth, Math.max(0, centerWidgets.x - root.gap - x))

        Widgets.Workspaces {}
        Widgets.Mpris {}
    }

    WidgetStrip {
        id: centerWidgets
        width: Math.min(idealWidth, Math.max(0, root.space - endWidgets.width - root.startReserve))
        x: {
            const latest = Math.max(root.leftEdge, endWidgets.x - root.gap - width);
            const earliest = Math.min(latest, root.leftEdge + root.gap + startWidgets.idealWidth);
            return Math.min(latest, Math.max(earliest, (root.width - width) / 2));
        }

        Loader {
            active: SessionTools.has("swaync-client")
            sourceComponent: Widgets.Notifications {}
        }
        Widgets.Clock {}
        Widgets.Tray {}
    }

    WidgetStrip {
        id: endWidgets
        width: Math.min(idealWidth, Math.max(root.space / 2, root.space - centerWidgets.idealWidth - root.startReserve))
        x: root.rightEdge - width
        contentX: Math.max(0, contentWidth - width)

        Widgets.Hardware {}
        Widgets.Battery {}
        Widgets.Network {}
        Widgets.Audio {}
        Widgets.Power {}
    }
}
