import QtQuick
import Quickshell.Io
import Quickshell.Networking
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    property var devices: Networking.devices ? Networking.devices.values : []
    property var wiredDevice: findConnectedDevice(DeviceType.Wired)
    property var wifiDevice: findConnectedDevice(DeviceType.Wifi)
    property var activeDevice: wiredDevice || wifiDevice
    property string interfaceName: activeDevice ? activeDevice.name : ""
    property var connectedNetwork: findConnectedNetwork(wifiDevice)
    property string connectionType: wiredDevice ? "wired" : connectedNetwork ? "wifi" : "offline"
    property string ipAddress: ""
    property real rxRate: 0
    property real txRate: 0
    property real previousRx: 0
    property real previousTx: 0
    property double previousSampleMs: 0
    property string addressRequestInterface: ""
    property bool addressRefreshPending: false

    implicitWidth: bubble.implicitWidth
    implicitHeight: bubble.implicitHeight

    function findConnectedDevice(type) {
        const currentDevices = devices || [];
        for (let index = 0; index < currentDevices.length; index++) {
            const device = currentDevices[index];
            if (device && device.type === type && device.connected)
                return device;
        }
        return null;
    }

    function findConnectedNetwork(device) {
        if (!device || !device.networks)
            return null;

        const networks = device.networks.values || [];
        for (let index = 0; index < networks.length; index++) {
            if (networks[index] && networks[index].connected)
                return networks[index];
        }
        return null;
    }

    function wifiIcon(strength) {
        if (strength > 0.8)
            return "󰤨";
        if (strength > 0.6)
            return "󰤥";
        if (strength > 0.4)
            return "󰤢";
        return "󰤟";
    }

    function formatSpeed(bytesPerSecond) {
        function format(value, unit) {
            const valueText = value >= 100 ? value.toFixed(1) : value.toFixed(2).padStart(5);
            return `${valueText}${unit}`;
        }

        if (bytesPerSecond >= 1024 * 1024)
            return format(bytesPerSecond / 1024 / 1024, "M");
        if (bytesPerSecond >= 1024)
            return format(bytesPerSecond / 1024, "K");
        return format(bytesPerSecond, "B");
    }

    function refreshTraffic() {
        if (interfaceName.length > 0 && !trafficProcess.running)
            trafficProcess.exec(["cat", "/proc/net/dev"]);
    }

    function consumeTraffic(output) {
        if (interfaceName.length === 0)
            return;
        const lines = output.split("\n");
        const line = lines.find(candidate => candidate.trim().startsWith(`${interfaceName}:`));
        if (!line)
            return;
        const fields = line.trim().split(":")[1].trim().split(/\s+/);
        const received = Number(fields[0]);
        const sent = Number(fields[8]);
        const now = Date.now();
        if (previousSampleMs > 0) {
            const seconds = (now - previousSampleMs) / 1000;
            if (seconds > 0) {
                rxRate = Math.max(0, received - previousRx) / seconds;
                txRate = Math.max(0, sent - previousTx) / seconds;
            }
        }
        previousRx = received;
        previousTx = sent;
        previousSampleMs = now;
    }

    function refreshAddress() {
        ipAddress = "";
        if (interfaceName.length === 0)
            return;
        if (ipProcess.running) {
            if (addressRequestInterface !== interfaceName)
                addressRefreshPending = true;
            return;
        }

        addressRefreshPending = false;
        addressRequestInterface = interfaceName;
        ipProcess.exec(["sh", "-c", "ip -4 -o addr show dev \"$1\" scope global | awk '{print $4}'", "sh", addressRequestInterface]);
    }

    function completeAddressRefresh(address) {
        if (addressRequestInterface === interfaceName)
            ipAddress = address.trim();
        addressRequestInterface = "";
        if (addressRefreshPending)
            refreshAddress();
    }

    onInterfaceNameChanged: {
        previousRx = 0;
        previousTx = 0;
        previousSampleMs = 0;
        rxRate = 0;
        txRate = 0;
        refreshAddress();
        refreshTraffic();
    }

    Primitives.Bubble {
        id: bubble
        implicitWidth: content.implicitWidth + Shell.Theme.bubblePadding * 2
        implicitHeight: Shell.Theme.widgetHeight
        hovered: mouseArea.containsMouse

        Primitives.ThemeText {
            id: content
            anchors.centerIn: parent
            text: {
                if (root.connectionType === "wired")
                    return "󰈀 LAN";
                if (root.connectionType === "offline")
                    return "󰤭 Offline";

                const network = root.connectedNetwork;
                return network ? `${root.wifiIcon(network.signalStrength)}  ⇣ ${root.formatSpeed(root.rxRate)} ⇡ ${root.formatSpeed(root.txRate)}` : "󰤭 Offline";
            }
            color: root.connectionType === "wired" ? Shell.Theme.teal : root.connectionType === "offline" ? Shell.Theme.red : Shell.Theme.teal
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
        }
    }
    Shell.BarTooltip {
        target: mouseArea
        text: {
            if (root.connectionType === "offline")
                return "Not connected";
            if (root.connectionType === "wired")
                return root.ipAddress.length > 0 ? `${root.interfaceName}\n${root.ipAddress}` : root.interfaceName;
            const network = root.connectedNetwork;
            if (!network)
                return "Not connected";
            const signal = Math.round(network.signalStrength * 100);
            const ipLine = root.ipAddress.length > 0 ? `\nIP: ${root.ipAddress}` : "";
            return `${network.name} · ${root.interfaceName}${ipLine}\nSignal: ${signal}%`;
        }
        hovered: mouseArea.containsMouse
    }

    Process {
        id: trafficProcess
        stdout: StdioCollector {
            onStreamFinished: root.consumeTraffic(text)
        }
    }

    Process {
        id: ipProcess
        stdout: StdioCollector {
            onStreamFinished: root.completeAddressRefresh(text)
        }
    }

    Timer {
        interval: Shell.Theme.networkAddressRefreshInterval
        running: root.interfaceName.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshAddress()
    }

    Timer {
        interval: Shell.Theme.networkTrafficInterval
        running: root.interfaceName.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshTraffic()
    }
}
