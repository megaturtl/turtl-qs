import QtQuick
import Quickshell.Io
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    implicitWidth: content.implicitWidth + Shell.Theme.bubblePadding * 2
    implicitHeight: Shell.Theme.widgetHeight
    Primitives.Bubble {
        anchors.fill: parent
        hovered: mouse.containsMouse
    }

    property int overall: 0
    property var cores: []
    property int memPercent: 0
    property string temperature: "N/A"
    property real memUsed: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property var previousOverall: null
    property var previousCores: []
    property string temperaturePath: ""
    readonly property string temperatureDiscoveryCommand: "for zone in /sys/class/thermal/thermal_zone*; do\n" + "    type=$(cat \"$zone/type\" 2>/dev/null) || continue\n" + "    case \"$type\" in\n" + "        x86_pkg_temp|cpu-thermal|cpu_thermal|soc_thermal)\n" + "            [ -r \"$zone/temp\" ] && { printf '%s\\n' \"$zone/temp\"; exit 0; }\n" + "            ;;\n" + "    esac\n" + "done\n" + "for hwmon in /sys/class/hwmon/hwmon*; do\n" + "    name=$(cat \"$hwmon/name\" 2>/dev/null) || continue\n" + "    case \"$name\" in\n" + "        coretemp|k10temp|zenpower|cpu_thermal) ;;\n" + "        *) continue ;;\n" + "    esac\n" + "    for input in \"$hwmon\"/temp*_input; do\n" + "        label=$(cat \"${input%_input}_label\" 2>/dev/null)\n" + "        case \"$label\" in\n" + "            \"Package id \"*|Tctl|Tdie|CPU*) printf '%s\\n' \"$input\"; exit 0 ;;\n" + "        esac\n" + "    done\n" + "    for input in \"$hwmon\"/temp*_input; do\n" + "        [ -r \"$input\" ] && { printf '%s\\n' \"$input\"; exit 0; }\n" + "    done\n" + "done\n"

    function parseStat(line) {
        const fields = line.trim().split(/\s+/);
        let total = 0;
        for (let index = 1; index < fields.length; index++)
            total += Number(fields[index]) || 0;
        return {
            idle: Number(fields[4]) || 0,
            total: total
        };
    }

    function percent(current, previous) {
        const totalDelta = current.total - previous.total;
        return totalDelta <= 0 ? 0 : Math.round((1 - (current.idle - previous.idle) / totalDelta) * 100);
    }

    function parseMemory() {
        const values = {};
        const lines = memoryText.split("\n");
        for (let index = 0; index < lines.length; index++) {
            const match = lines[index].match(/^(MemTotal|MemAvailable|SwapTotal|SwapFree):\s+(\d+)/);
            if (match)
                values[match[1]] = Number(match[2]) * 1024;
        }
        const total = values.MemTotal || 0;
        const used = Math.max(0, total - (values.MemAvailable || 0));
        const totalSwap = values.SwapTotal || 0;
        return {
            total: total,
            used: used,
            swapTotal: totalSwap,
            swapUsed: Math.max(0, totalSwap - (values.SwapFree || 0))
        };
    }

    function updateCpu() {
        const lines = cpuText.split("\n");
        let aggregate = null;
        const coreStats = [];
        for (let index = 0; index < lines.length; index++) {
            if (/^cpu\s/.test(lines[index]))
                aggregate = parseStat(lines[index]);
            else if (/^cpu\d+\s/.test(lines[index]))
                coreStats.push(parseStat(lines[index]));
        }

        if (aggregate) {
            overall = previousOverall ? percent(aggregate, previousOverall) : 0;
            const percentages = [];
            for (let index = 0; index < coreStats.length; index++)
                percentages.push(previousCores[index] ? percent(coreStats[index], previousCores[index]) : 0);
            cores = percentages;
            previousOverall = aggregate;
            previousCores = coreStats;
        }
    }

    function updateMemory() {
        const memory = parseMemory();
        memUsed = memory.used;
        memTotal = memory.total;
        swapUsed = memory.swapUsed;
        swapTotal = memory.swapTotal;
        memPercent = memTotal > 0 ? Math.round(memUsed / memTotal * 100) : 0;
    }

    function updateTemp(rawTemperature) {
        const degrees = Number(rawTemperature.trim());
        temperature = Number.isFinite(degrees) ? Math.round(degrees / 1000) + "°" : "N/A";
    }

    function poll() {
        if (!cpuProcess.running)
            cpuProcess.exec(["cat", "/proc/stat"]);
        if (!memoryProcess.running)
            memoryProcess.exec(["cat", "/proc/meminfo"]);
        if (temperaturePath.length > 0 && !temperatureProcess.running)
            temperatureProcess.exec(["cat", temperaturePath]);
    }

    function pad3(value) {
        return String(value).padStart(3);
    }
    function formatCores() {
        const lines = [];
        for (let index = 0; index < cores.length; index += 2) {
            let line = "Core " + index + ": " + cores[index] + "%";
            if (index + 1 < cores.length)
                line += "  Core " + (index + 1) + ": " + cores[index + 1] + "%";
            lines.push(line);
        }
        return lines.join("\n");
    }

    property string cpuText: ""
    property string memoryText: ""

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8

        Primitives.ThemeText {
            text: "󰍛" + root.pad3(root.overall) + "%"
            color: Shell.Theme.mauve
        }

        Primitives.ThemeText {
            text: "󰔏 " + root.pad3(root.temperature)
            color: Shell.Theme.peach
        }

        Primitives.ThemeText {
            text: " " + root.pad3(root.memPercent) + "%"
            color: Shell.Theme.blue
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
    }
    Shell.BarTooltip {
        target: mouse
        text: root.formatCores() + "\n────────────────\nRAM:  " + Shell.Theme.formatBytes(root.memUsed) + " / " + Shell.Theme.formatBytes(root.memTotal) + "\nSwap: " + Shell.Theme.formatBytes(root.swapUsed) + " / " + Shell.Theme.formatBytes(root.swapTotal)
        hovered: mouse.containsMouse
    }

    Process {
        id: cpuProcess
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuText = text;
                root.updateCpu();
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: memoryProcess
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.memoryText = text;
                root.updateMemory();
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: temperaturePathProcess
        running: true
        command: ["sh", "-c", root.temperatureDiscoveryCommand]
        stdout: StdioCollector {
            onStreamFinished: {
                root.temperaturePath = text.trim();
                root.poll();
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: temperatureProcess
        stdout: StdioCollector {
            onStreamFinished: root.updateTemp(text)
        }
        stderr: StdioCollector {}
    }

    Timer {
        interval: Shell.Theme.hardwarePollInterval
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }
}
