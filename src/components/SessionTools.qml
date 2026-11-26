pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var commands: []

    function has(executable) {
        return commands.includes(executable);
    }

    property Process discovery: Process {
        command: ["sh", "-c", "for tool do command -v \"$tool\" >/dev/null && printf '%s\\n' \"$tool\"; done", "sh", "swaync-client", "wlogout", "hyprlock", "pwvucontrol", "powerprofilesctl", "niri"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.commands = text.trim().split("\n")
        }
    }
}
