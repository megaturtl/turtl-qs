pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property color rosewater: "#f5e0dc"
    readonly property color flamingo: "#f2cdcd"
    readonly property color pink: "#f5c2e7"
    readonly property color mauve: "#cba6f7"
    readonly property color red: "#f38ba8"
    readonly property color maroon: "#eba0ac"
    readonly property color peach: "#fab387"
    readonly property color yellow: "#f9e2af"
    readonly property color green: "#a6e3a1"
    readonly property color teal: "#94e2d5"
    readonly property color sky: "#89dceb"
    readonly property color sapphire: "#74c7ec"
    readonly property color blue: "#89b4fa"
    readonly property color lavender: "#b4befe"
    readonly property color text: "#cdd6f4"
    readonly property color subtext1: "#bac2de"
    readonly property color subtext0: "#a6adc8"
    readonly property color overlay2: "#9399b2"
    readonly property color overlay1: "#7f849c"
    readonly property color overlay0: "#6c7086"
    readonly property color surface2: "#585b70"
    readonly property color surface1: "#45475a"
    readonly property color surface0: "#313244"
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color crust: "#11111b"

    readonly property color bubbleBackground: mantle
    readonly property color bubbleBorder: base
    readonly property color bubbleHover: surface1
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 14

    readonly property int barHeight: 36
    readonly property int widgetHeight: 24
    readonly property int bubbleRadius: 8
    readonly property int bubblePadding: 12
    readonly property int widgetSpacing: 6
    readonly property int barPaddingX: 6
    readonly property int bubbleHoverDuration: 120
    readonly property int mprisProgressHeight: 2
    readonly property int mprisProgressInset: 8

    readonly property int tooltipDelay: 400
    readonly property int osdStartupDelay: 800
    readonly property int osdTimeout: 1500
    readonly property int batteryProfileRefreshDelay: 250
    readonly property int batteryPollInterval: 10000
    readonly property int clockInterval: 1000
    readonly property int hardwarePollInterval: 2000
    readonly property int mprisPositionInterval: 250
    readonly property int networkAddressRefreshInterval: 30000
    readonly property int networkTrafficInterval: 2000
    readonly property int notificationReconnectDelay: 1000
    readonly property int workspacePollInterval: 1000

    function volumeIcon(value, muted) {
        if (muted)
            return "󰝟";
        if (value > 0.66)
            return "󰕾";
        if (value > 0.33)
            return "󰖀";
        return "󰕿";
    }

    function brightnessIcon(value) {
        if (value > 0.66)
            return "󰃠";
        if (value > 0.33)
            return "󰃟";
        return "󰃞";
    }

    function formatBytes(bytes) {
        if (!isFinite(bytes) || bytes <= 0)
            return "0 B";

        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let value = bytes;
        let unit = 0;
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit += 1;
        }
        return `${value < 10 && unit > 0 ? value.toFixed(1) : Math.round(value)} ${units[unit]}`;
    }

    function withAlpha(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }
}
