import QtQuick
import Quickshell.Services.Mpris
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    implicitWidth: player ? 240 : 0
    implicitHeight: Shell.Theme.widgetHeight

    readonly property var availablePlayers: Mpris.players.values.filter(candidate => !candidate.dbusName.includes("playerctld"))
    readonly property var playing: availablePlayers.find(candidate => candidate.isPlaying) ?? null
    property var lastPlaying: null
    readonly property var player: playing ?? selectFallback()
    readonly property real elapsed: player?.positionSupported ? Math.max(0, player.position) : -1
    readonly property bool durationKnown: (player?.lengthSupported ?? false) && player.length > 0
    readonly property string trackTime: {
        const position = formatTime(elapsed);
        return durationKnown && position ? position + "/" + formatTime(player.length) : position;
    }

    onPlayingChanged: {
        if (playing)
            lastPlaying = playing;
    }

    function selectFallback() {
        if (lastPlaying && availablePlayers.includes(lastPlaying))
            return lastPlaying;
        const paused = availablePlayers.filter(candidate => candidate.playbackState === MprisPlaybackState.Paused);
        return paused.find(candidate => !isBrowser(candidate)) ?? paused[0] ?? availablePlayers[0] ?? null;
    }

    function isBrowser(player) {
        return /firefox|chrome|chromium/i.test(player.dbusName);
    }

    function iconFor(player) {
        if (/spotify/i.test(player.dbusName))
            return "󰓇";
        if (/vlc/i.test(player.dbusName))
            return "󰕼";
        return "󰝚";
    }
    function formatTime(seconds) {
        if (seconds === undefined || seconds === null || seconds < 0)
            return "";
        const whole = Math.floor(seconds);
        return Math.floor(whole / 60) + ":" + String(whole % 60).padStart(2, "0");
    }

    Timer {
        interval: Shell.Theme.mprisPositionInterval
        running: (root.player?.isPlaying ?? false) && root.player.positionSupported
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Primitives.Bubble {
        id: bubble
        anchors.fill: parent
        visible: root.player !== null
        clip: true
        hovered: mouse.containsMouse

        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                width: parent.width
                height: parent.height - progressTrack.height - bubble.border.width

                Primitives.ThemeText {
                    id: playerIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Shell.Theme.bubblePadding
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.player ? root.iconFor(root.player) : ""
                    color: Shell.Theme.pink
                }

                Item {
                    id: marquee
                    anchors.left: playerIcon.right
                    anchors.leftMargin: 8
                    anchors.right: playbackIcon.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: titleLabel.implicitHeight
                    clip: true

                    readonly property string trackText: root.player ? [root.player.trackArtist, root.player.trackTitle].filter(Boolean).join(" - ") : ""

                    Primitives.ThemeText {
                        id: titleLabel
                        y: 0
                        text: marquee.trackText
                        color: Shell.Theme.pink
                        elide: Text.ElideRight
                        width: Math.max(implicitWidth, marquee.width)
                    }

                    SequentialAnimation {
                        id: marqueeAnimation
                        running: marquee.trackText.length > 0 && titleLabel.implicitWidth > marquee.width
                        loops: Animation.Infinite
                        PauseAnimation {
                            duration: 1200
                        }
                        NumberAnimation {
                            target: titleLabel
                            property: "x"
                            to: -(titleLabel.implicitWidth - marquee.width)
                            duration: Math.max(1, (titleLabel.implicitWidth - marquee.width) * 50)
                        }
                        PauseAnimation {
                            duration: 1200
                        }
                        NumberAnimation {
                            target: titleLabel
                            property: "x"
                            to: 0
                            duration: Math.max(1, (titleLabel.implicitWidth - marquee.width) * 50)
                        }
                    }

                    onTrackTextChanged: titleLabel.x = 0
                }

                Primitives.ThemeText {
                    id: playbackIcon
                    anchors.right: parent.right
                    anchors.rightMargin: Shell.Theme.bubblePadding
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.player?.isPlaying ? "" : ""
                    color: Shell.Theme.pink
                }
            }

            Rectangle {
                id: progressTrack
                x: Shell.Theme.mprisProgressInset
                visible: root.durationKnown && root.elapsed >= 0
                width: parent.width - Shell.Theme.mprisProgressInset * 2
                height: Shell.Theme.mprisProgressHeight
                radius: height / 2
                color: Shell.Theme.surface0

                Rectangle {
                    width: parent.width * (progressTrack.visible ? Math.min(1, root.elapsed / root.player.length) : 0)
                    height: parent.height
                    radius: parent.radius
                    color: Shell.Theme.pink
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: function (event) {
                if (!root.player)
                    return;
                if (event.button === Qt.LeftButton && root.player.canTogglePlaying)
                    root.player.togglePlaying();
                else if (event.button === Qt.MiddleButton && root.player.canGoPrevious)
                    root.player.previous();
                else if (event.button === Qt.RightButton && root.player.canGoNext)
                    root.player.next();
            }
            onWheel: function (wheel) {
                if (root.player?.canSeek && wheel.angleDelta.y !== 0)
                    root.player.seek(wheel.angleDelta.y > 0 ? 5 : -5);
            }
        }
    }
    Shell.BarTooltip {
        target: mouse
        text: root.player ? [root.player.trackTitle, root.player.trackArtist, root.player.trackAlbum, root.trackTime, "────────────────", "Left · play/pause", "Middle · previous", "Right · next", "Scroll · seek 5 seconds"].filter(Boolean).join("\n") : ""
        hovered: mouse.containsMouse
    }
}
