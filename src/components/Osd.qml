import QtQuick

Item {
    id: root

    required property OsdState sharedState

    implicitWidth: bubble.implicitWidth
    implicitHeight: bubble.implicitHeight
    visible: sharedState.osdVisible || bubble.opacity > 0

    Rectangle {
        id: bubble
        anchors.centerIn: parent
        implicitWidth: contentRow.implicitWidth + 36
        implicitHeight: 56
        radius: 14
        color: Theme.withAlpha(Theme.base, 0.55)
        opacity: root.sharedState.osdVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 14

            Text {
                width: 22
                text: root.sharedState.osdKind === "volume" ? Theme.volumeIcon(root.sharedState.osdValue, root.sharedState.osdMuted) : Theme.brightnessIcon(root.sharedState.osdValue)
                color: root.sharedState.osdKind === "brightness" ? Theme.yellow : root.sharedState.osdMuted ? Theme.overlay0 : Theme.sky
                font.family: Theme.fontFamily
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                width: 140
                height: 4
                anchors.verticalCenter: parent.verticalCenter
                radius: height / 2
                color: Theme.withAlpha(Theme.overlay0, 0.35)

                Rectangle {
                    width: parent.width * root.sharedState.osdValue
                    height: parent.height
                    radius: height / 2
                    color: root.sharedState.osdKind === "brightness" ? Theme.yellow : root.sharedState.osdMuted ? Theme.overlay0 : Theme.sky
                }
            }

            Text {
                width: 52
                text: root.sharedState.osdKind === "volume" && root.sharedState.osdMuted ? "muted" : `${Math.round(root.sharedState.osdValue * 100)}%`
                color: root.sharedState.osdKind === "volume" && root.sharedState.osdMuted ? Theme.overlay0 : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
