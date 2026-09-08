import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    property var battery: UPower.displayDevice
    property string activeProfile: ""
    property bool profileAvailable: activeProfile.length > 0
    property bool batteryPresent: battery && battery.ready && battery.isLaptopBattery && battery.powerSupply && battery.isPresent
    property bool charging: batteryPresent && battery.state === UPowerDeviceState.Charging
    property int percentage: batteryPresent ? Math.round(battery.percentage) : 0

    implicitWidth: batteryPresent ? bubble.implicitWidth : 0
    implicitHeight: batteryPresent ? bubble.implicitHeight : 0
    visible: batteryPresent

    function batteryIcon(value, isCharging) {
        if (isCharging)
            return "󰂄";
        if (value >= 90)
            return "󰁹";
        if (value >= 80)
            return "󰂂";
        if (value >= 70)
            return "󰂁";
        if (value >= 60)
            return "󰂀";
        if (value >= 50)
            return "󰁿";
        if (value >= 40)
            return "󰁾";
        if (value >= 30)
            return "󰁽";
        if (value >= 20)
            return "󰁼";
        if (value >= 10)
            return "󰁻";
        return "󰂃";
    }

    function profileIcon(profile) {
        if (profile === "power-saver")
            return "󰌪";
        if (profile === "performance")
            return "󱐋";
        return "󰾅";
    }
    function formatTime(seconds) {
        if (seconds <= 0)
            return "";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
    }

    function refreshProfile() {
        if (batteryPresent && !profileQuery.running)
            profileQuery.exec(["powerprofilesctl", "get"]);
    }

    function cycleProfile() {
        if (!batteryPresent || !profileAvailable || profileSet.running)
            return;
        const profiles = ["power-saver", "balanced", "performance"];
        const index = profiles.indexOf(activeProfile);
        profileSet.exec(["powerprofilesctl", "set", profiles[(index + 1) % profiles.length]]);
    }

    Primitives.Bubble {
        id: bubble
        implicitWidth: content.implicitWidth + Shell.Theme.bubblePadding * 2
        implicitHeight: Shell.Theme.widgetHeight
        hovered: mouseArea.containsMouse

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 4

            Primitives.ThemeText {
                text: `${root.batteryIcon(root.percentage, root.charging)} ${root.percentage}%`
                color: root.charging ? Shell.Theme.green : root.percentage <= 15 ? Shell.Theme.red : root.percentage <= 30 ? Shell.Theme.peach : Shell.Theme.text
            }

            Primitives.ThemeText {
                visible: root.profileAvailable
                text: root.profileIcon(root.activeProfile)
                color: root.charging ? Shell.Theme.green : root.percentage <= 15 ? Shell.Theme.red : root.percentage <= 30 ? Shell.Theme.peach : Shell.Theme.text
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.cycleProfile()
        }
    }
    Shell.BarTooltip {
        target: mouseArea
        text: {
            if (!root.batteryPresent)
                return "";
            const time = root.charging ? (root.battery.timeToFull > 0 ? `Full in ${root.formatTime(root.battery.timeToFull)}` : "Charging") : (root.battery.timeToEmpty > 0 ? `${root.formatTime(root.battery.timeToEmpty)} remaining` : "");
            const profile = root.profileAvailable ? `Profile: ${root.activeProfile}` : "";
            return [`Battery: ${root.percentage}%`, time, profile].filter(line => line.length > 0).join("\n");
        }
        hovered: mouseArea.containsMouse
    }

    Process {
        id: profileQuery
        stdout: StdioCollector {
            onStreamFinished: root.activeProfile = text.trim()
        }
    }

    Process {
        id: profileSet
        onExited: profileRefresh.restart()
    }

    Timer {
        id: profileRefresh
        interval: Shell.Theme.batteryProfileRefreshDelay
        onTriggered: root.refreshProfile()
    }

    Timer {
        interval: Shell.Theme.batteryPollInterval
        running: root.batteryPresent
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshProfile()
    }
}
