//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Wayland
import "components" as Shell

ShellRoot {
    id: root

    Shell.Osd {
        id: osdState
    }

    Variants {
        model: Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : []

        PanelWindow {
            required property var modelData

            screen: modelData
            anchors {
                top: true
                left: true
                right: true
            }
            exclusiveZone: implicitHeight
            focusable: false
            color: "transparent"
            implicitHeight: bar.implicitHeight
            WlrLayershell.layer: WlrLayer.Top

            Shell.Bar {
                id: bar
                anchors.fill: parent
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            anchors.top: true
            margins.top: 44
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            color: "transparent"
            implicitWidth: osd.implicitWidth
            implicitHeight: osd.implicitHeight
            mask: Region {
                width: 0
                height: 0
            }
            WlrLayershell.layer: WlrLayer.Overlay

            Shell.Osd {
                id: osd
                anchors.centerIn: parent
                sharedState: osdState
            }
        }
    }
}
