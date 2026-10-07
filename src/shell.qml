//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Wayland
import "components" as Shell

ShellRoot {
    id: root

    property var screens: Quickshell.screens
    property string barScreenName: ""
    readonly property var barScreens: barScreenName === "" ? [] : screens.filter(screen => screen.name === barScreenName)

    function rememberBarScreen() {
        if (barScreenName === "" && screens.length > 0)
            barScreenName = screens[0].name;
    }

    onScreensChanged: rememberBarScreen()
    Component.onCompleted: rememberBarScreen()

    Shell.Osd {
        id: osdState
    }

    Variants {
        model: root.barScreens

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
        model: root.screens

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
