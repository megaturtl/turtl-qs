import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import ".." as Shell
import "../primitives" as Primitives

Item {
    id: root

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: Shell.Theme.widgetHeight

    readonly property bool isNiri: Quickshell.env("NIRI_SOCKET") !== null
    property int hyprlandToplevelRevision: 0
    property var niriWorkspaces: []
    property var niriWindows: []
    readonly property var niriVisibleWorkspaces: {
        const focused = niriWorkspaces.find(workspace => workspace.is_focused);
        return niriWorkspaces.filter(workspace => workspace.output === focused?.output);
    }
    property var workspaceIds: [1, 2, 3, 4, 5]

    function recomputeWorkspaceIds() {
        const known = isNiri ? niriVisibleWorkspaces.map(workspace => workspace.idx) : Hyprland.workspaces.values.map(workspace => workspace.id);
        const next = [...new Set([1, 2, 3, 4, 5].concat(known))].sort((left, right) => left - right);
        if (next.length !== workspaceIds.length || next.some((value, index) => value !== workspaceIds[index]))
            workspaceIds = next;
    }

    Component.onCompleted: recomputeWorkspaceIds()

    Connections {
        target: Hyprland.workspaces
        function onObjectInsertedPost() {
            root.recomputeWorkspaceIds();
        }
        function onObjectRemovedPost() {
            root.recomputeWorkspaceIds();
        }
    }

    function scheduleHyprlandToplevelRefresh() {
        if (isNiri)
            return;
        Hyprland.refreshToplevels();
        hyprlandToplevelRevisionTimer.restart();
    }

    Timer {
        id: hyprlandToplevelRevisionTimer
        interval: 50
        onTriggered: root.hyprlandToplevelRevision++
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (root.isNiri || ["openwindow", "closewindow", "movewindow", "movewindowv2", "windowtitle"].indexOf(event.name) === -1)
                return;
            root.scheduleHyprlandToplevelRefresh();
        }
    }

    onNiriVisibleWorkspacesChanged: recomputeWorkspaceIds()

    function iconFor(windowClass, title) {
        if (/bitwarden/i.test(windowClass))
            return "  ";
        if (/stremio/i.test(windowClass))
            return " 󰎁 ";
        if (/firefox|librewolf|zen/i.test(windowClass))
            return " 󰈹 ";
        if (/kitty|konsole|ghostty|wezterm|foot|footclient/i.test(windowClass))
            return "  ";
        if (/thunderbird/i.test(windowClass))
            return "   ";
        if (/gmail/i.test(title))
            return " 󰊫 ";
        if (/discord|webcord|vesktop/i.test(windowClass))
            return "  ";
        if (/youtube/i.test(title))
            return "   ";
        if (/vlc/i.test(windowClass))
            return " 󰕼 ";
        if (/spotify/i.test(windowClass))
            return " 󰓇 ";
        if (/minecraft|prismlauncher|waywall/i.test(windowClass))
            return " 󰍳 ";
        if (/vscode|codium/i.test(windowClass))
            return " 󰨞 ";
        if (/github/i.test(title))
            return " 󰊤 ";
        if (/nvim/i.test(title))
            return "  ";
        if (/vim/i.test(title))
            return "  ";
        if (/jetbrains-idea/i.test(windowClass))
            return "  ";
        if (/polkit/i.test(windowClass))
            return " 󰒃 ";
        if (/pavucontrol|pwvucontrol/i.test(windowClass))
            return " 󱡫 ";
        if (/steam/i.test(windowClass))
            return " 󰓓 ";
        if (/dolphin|thunar|nemo/i.test(windowClass))
            return " 󰉋 ";
        if (/gimp/i.test(windowClass))
            return "  ";
        if (/tauon|feishin|audacious/i.test(windowClass))
            return " 󰝚 ";
        if (/logseq|affine|obsidian/i.test(windowClass))
            return " 󰠮 ";
        if (/obsproject/i.test(windowClass))
            return " 󰄄 ";
        return "";
    }

    function clientsFor(id) {
        if (isNiri) {
            const workspace = niriVisibleWorkspaces.find(candidate => candidate.idx === id);
            if (!workspace)
                return [];
            return niriWindows.filter(window => window.workspace_id === workspace.id).map(window => ({
                        windowClass: window.app_id ?? "",
                        title: window.title ?? ""
                    }));
        }

        const workspace = Hyprland.workspaces.values.find(candidate => candidate.id === id);
        return workspace?.toplevels.values.map(window => ({
                    windowClass: window.lastIpcObject?.["class"] ?? "",
                    title: window.title ?? ""
                })) ?? [];
    }

    function iconsFor(id) {
        const icons = [];
        for (const client of clientsFor(id)) {
            const icon = iconFor(client.windowClass, client.title);
            if (icon && icons.indexOf(icon) === -1)
                icons.push(icon);
        }
        return icons;
    }

    function focused(id) {
        if (isNiri)
            return niriVisibleWorkspaces.some(workspace => workspace.idx === id && workspace.is_focused);
        return Hyprland.workspaces.values.some(workspace => workspace.id === id && workspace.focused);
    }

    function activate(id) {
        if (isNiri)
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(id)]);
        else
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ workspace = "' + id + '" })']);
    }

    function scroll(delta) {
        if (delta === 0)
            return;
        if (isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", delta > 0 ? "focus-workspace-down" : "focus-workspace-up"]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ workspace = "' + (delta > 0 ? "e+1" : "e-1") + '" })']);
        }
    }

    function pollNiri() {
        if (!isNiri)
            return;
        if (!niriWorkspacesProcess.running)
            niriWorkspacesProcess.running = true;
        if (!niriWindowsProcess.running)
            niriWindowsProcess.running = true;
    }

    Process {
        id: niriWorkspacesProcess
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.niriWorkspaces = JSON.parse(text);
                } catch (_) {
                    root.niriWorkspaces = [];
                }
            }
        }
    }

    Process {
        id: niriWindowsProcess
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.niriWindows = JSON.parse(text);
                } catch (_) {
                    root.niriWindows = [];
                }
            }
        }
    }

    Timer {
        interval: Shell.Theme.workspacePollInterval
        running: root.isNiri
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pollNiri()
    }

    Row {
        id: workspaceRow
        spacing: 6

        Repeater {
            model: root.workspaceIds

            delegate: Primitives.Bubble {
                id: workspace
                required property int modelData
                readonly property var icons: {
                    root.hyprlandToplevelRevision;
                    return root.iconsFor(modelData);
                }
                readonly property bool active: root.focused(modelData)

                width: Math.max(22, content.implicitWidth + 16)
                height: Shell.Theme.widgetHeight
                hovered: mouse.containsMouse
                background: workspace.active ? Shell.Theme.lavender : Shell.Theme.bubbleBackground
                accent: workspace.active ? Shell.Theme.lavender : Shell.Theme.bubbleHover

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 0

                    Primitives.ThemeText {
                        text: workspace.modelData
                        color: workspace.active ? Shell.Theme.base : (workspace.icons.length ? Shell.Theme.text : Shell.Theme.overlay1)
                        font.bold: workspace.active
                    }

                    Repeater {
                        model: workspace.icons

                        delegate: Primitives.ThemeText {
                            required property string modelData
                            text: modelData
                            color: workspace.active ? Shell.Theme.base : Shell.Theme.text
                            font.bold: workspace.active
                        }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.activate(workspace.modelData)
                    onWheel: wheel => root.scroll(wheel.angleDelta.y)
                }

                Shell.BarTooltip {
                    target: mouse
                    text: workspace.icons.length ? "Workspace " + workspace.modelData + "\n" + workspace.icons.join("").trim() : "Workspace " + workspace.modelData
                    hovered: mouse.containsMouse
                }
            }
        }
    }
}
