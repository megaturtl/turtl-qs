import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    property var battery: UPower.displayDevice
    property var profileState: null
    readonly property string activeProfile: profileState?.active ?? ""
    readonly property bool profileAvailable: activeProfile.length > 0
    property bool batteryPresent: battery && battery.ready && battery.isLaptopBattery && battery.powerSupply && battery.isPresent
    property bool charging: batteryPresent && battery.state === UPowerDeviceState.Charging
    property int percentage: batteryPresent ? Math.round(battery.percentage * 100) : 0

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

    function formatPower(rate, state) {
        if (!Number.isFinite(rate) || rate === 0)
            return "";
        const sign = state === UPowerDeviceState.Discharging ? "-" : state === UPowerDeviceState.Charging ? "+" : "";
        return `Power: ${sign}${Math.abs(rate).toFixed(1)} W`;
    }

    function readProfiles(output) {
        let active = "";
        const profiles = [];
        for (const line of output.split("\n")) {
            const heading = /^([* ]) ([a-z0-9-]+):$/.exec(line);
            if (!heading)
                continue;
            profiles.unshift(heading[2]);
            if (heading[1] === "*")
                active = heading[2];
        }
        profileState = active ? {
            active,
            profiles
        } : null;
    }

    function refreshProfile() {
        if (batteryPresent && Shell.SessionTools.has("powerprofilesctl") && !profileQuery.running && !profileSet.running)
            profileQuery.running = true;
    }

    function cycleProfile() {
        if (!batteryPresent || !profileAvailable || profileQuery.running || profileSet.running)
            return;
        const profiles = profileState.profiles;
        if (profiles.length > 1)
            profileSet.exec(["powerprofilesctl", "set", profiles[(profiles.indexOf(activeProfile) + 1) % profiles.length]]);
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
            const power = root.formatPower(root.battery.changeRate, root.battery.state);
            return [`Battery: ${root.percentage}%`, time, power, profile].filter(line => line.length > 0).join("\n");
        }
        hovered: mouseArea.containsMouse
    }

    Process {
        id: profileQuery
        command: ["powerprofilesctl", "list"]
        environment: ({
                LC_ALL: "C"
            })
        stdout: StdioCollector {
            id: profileOutput
        }
        onExited: (code, status) => root.readProfiles(code === 0 && status === 0 ? profileOutput.text : "")
    }

    Process {
        id: profileSet
        onExited: root.refreshProfile()
    }

    Timer {
        interval: Shell.Theme.batteryPollInterval
        running: root.batteryPresent && Shell.SessionTools.has("powerprofilesctl")
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshProfile()
    }
}
