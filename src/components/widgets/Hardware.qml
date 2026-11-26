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
    property var previousCores: ({})
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
        const idleDelta = current.idle - previous.idle;
        return totalDelta <= 0 || idleDelta < 0 ? 0 : Math.max(0, Math.round((1 - idleDelta / totalDelta) * 100));
    }

    function parseMemory(memoryText) {
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

    function updateCpu(cpuText) {
        let aggregate = null;
        const coreStats = {};
        const percentages = [];
        for (const line of cpuText.split("\n")) {
            const match = /^cpu(\d+)?\s/.exec(line);
            if (!match)
                continue;
            const sample = parseStat(line);
            const id = match[1];
            if (id === undefined) {
                aggregate = sample;
            } else {
                const previous = previousCores[id];
                percentages.push({
                    id,
                    usage: previous ? percent(sample, previous) : 0
                });
                coreStats[id] = sample;
            }
        }
        if (!aggregate)
            return;
        overall = previousOverall ? percent(aggregate, previousOverall) : 0;
        cores = percentages;
        previousOverall = aggregate;
        previousCores = coreStats;
    }

    function updateMemory(memoryText) {
        const memory = parseMemory(memoryText);
        memUsed = memory.used;
        memTotal = memory.total;
        swapUsed = memory.swapUsed;
        swapTotal = memory.swapTotal;
        memPercent = memTotal > 0 ? Math.round(memUsed / memTotal * 100) : 0;
    }

    function updateTemp(rawTemperature) {
        const value = rawTemperature.trim();
        if (!/^-?\d+$/.test(value) || !Number.isFinite(Number(value))) {
            temperature = "N/A";
            temperaturePath = "";
            return;
        }
        temperature = Math.round(Number(value) / 1000) + "°";
    }

    function poll() {
        cpuFile.reload();
        memoryFile.reload();
        if (temperaturePath)
            temperatureFile.reload();
    }

    function pad3(value) {
        return String(value).padStart(3);
    }
    function formatCores() {
        const lines = [];
        for (let index = 0; index < cores.length; index += 2) {
            const first = cores[index];
            const second = cores[index + 1];
            let line = `Core ${first.id}: ${first.usage}%`;
            if (second)
                line += `  Core ${second.id}: ${second.usage}%`;
            lines.push(line);
        }
        return lines.join("\n");
    }

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

    FileView {
        id: cpuFile
        path: "/proc/stat"
        onTextChanged: root.updateCpu(text())
    }

    FileView {
        id: memoryFile
        path: "/proc/meminfo"
        onTextChanged: root.updateMemory(text())
    }

    Process {
        id: temperaturePathProcess
        command: ["sh", "-c", root.temperatureDiscoveryCommand]
        stdout: StdioCollector {
            onStreamFinished: root.temperaturePath = text.trim()
        }
        stderr: StdioCollector {}
    }

    FileView {
        id: temperatureFile
        path: root.temperaturePath
        printErrors: false
        onTextChanged: if (path)
            root.updateTemp(text())
        onLoadFailed: root.updateTemp("")
    }

    Component.onCompleted: temperaturePathProcess.running = true

    Timer {
        interval: 10000
        running: !root.temperaturePath
        repeat: true
        onTriggered: if (!temperaturePathProcess.running)
            temperaturePathProcess.running = true
    }

    Timer {
        interval: Shell.Theme.hardwarePollInterval
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }
}
