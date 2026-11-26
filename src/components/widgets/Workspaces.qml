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
    property int desktopEntriesRevision: 0
    property var niriWorkspaces: []
    property var niriWindows: []
    property var windowIcons: ({})
    readonly property string fallbackIcon: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="' + Shell.Theme.text + '" stroke-width="2"><rect x="2" y="3" width="20" height="18" rx="2"/><path d="M2 8h20M6 5.5h.01M9 5.5h.01"/></svg>')
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

    Component.onCompleted: {
        recomputeWorkspaceIds();
        refreshWindowIcons();
    }

    Connections {
        target: Hyprland.workspaces
        function onObjectInsertedPost() {
            root.recomputeWorkspaceIds();
        }
        function onObjectRemovedPost() {
            root.recomputeWorkspaceIds();
        }
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.desktopEntriesRevision++;
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
        onTriggered: {
            root.hyprlandToplevelRevision++;
            root.refreshWindowIcons();
        }
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

    function desktopEntryFor(identifiers) {
        for (const identifier of identifiers) {
            if (!identifier)
                continue;
            const entry = DesktopEntries.byId(identifier);
            if (entry)
                return entry;
        }

        for (const identifier of identifiers) {
            if (!identifier)
                continue;
            const entry = DesktopEntries.heuristicLookup(identifier);
            if (entry)
                return entry;
        }

        return null;
    }

    function clientsFor(id) {
        if (isNiri) {
            const workspace = niriVisibleWorkspaces.find(candidate => candidate.idx === id);
            if (!workspace)
                return [];
            return niriWindows.filter(window => window.workspace_id === workspace.id).map(window => ({
                        identifiers: [window.app_id ?? ""],
                        pid: window.pid
                    }));
        }

        const workspace = Hyprland.workspaces.values.find(candidate => candidate.id === id);
        return workspace?.toplevels.values.map(window => ({
                    identifiers: [window.handle?.appId ?? "", window.lastIpcObject?.["class"] ?? ""],
                    pid: window.lastIpcObject?.pid
                })) ?? [];
    }

    function iconFor(client) {
        const windowIcon = windowIcons[String(client.pid)];
        if (windowIcon)
            return windowIcon;
        const icon = desktopEntryFor(client.identifiers)?.icon ?? "";
        if (icon.startsWith("/"))
            return "file://" + icon.split("/").map(encodeURIComponent).join("/");
        return icon && Quickshell.hasThemeIcon(icon) ? Quickshell.iconPath(icon) : fallbackIcon;
    }

    function iconsFor(id) {
        const icons = [];
        for (const client of clientsFor(id)) {
            const icon = iconFor(client);
            if (icons.indexOf(icon) === -1)
                icons.push(icon);
        }
        return icons;
    }

    function focused(id) {
        if (isNiri)
            return niriVisibleWorkspaces.some(workspace => workspace.idx === id && workspace.is_focused);
        return Hyprland.workspaces.values.some(workspace => workspace.id === id && workspace.focused);
    }

    function dispatchHyprland(selector, special) {
        if (!Hyprland.focusedMonitor || /[\x00-\x1f\x7f]/.test(selector))
            return;
        if (Hyprland.usingLua) {
            const argument = JSON.stringify(selector);
            Hyprland.dispatch(special ? `hl.dsp.workspace.toggle_special(${argument})` : `hl.dsp.focus({ workspace = ${argument} })`);
        } else {
            Hyprland.dispatch(special ? `togglespecialworkspace ${selector}` : `workspace ${selector}`);
        }
    }

    function activate(id) {
        if (isNiri) {
            if (Shell.SessionTools.has("niri"))
                Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(id)]);
        } else {
            const workspace = Hyprland.workspaces.values.find(candidate => candidate.id === id);
            const name = workspace?.name ?? "";
            if (name === "special" || name.startsWith("special:"))
                dispatchHyprland(name === "special" ? "" : name.slice(8), true);
            else if (id > 0 || name)
                dispatchHyprland(id > 0 ? String(id) : `name:${name}`, false);
        }
    }

    function scroll(delta) {
        if (delta === 0)
            return;
        if (isNiri) {
            if (Shell.SessionTools.has("niri"))
                Quickshell.execDetached(["niri", "msg", "action", delta > 0 ? "focus-workspace-down" : "focus-workspace-up"]);
        } else {
            dispatchHyprland(delta > 0 ? "e+1" : "e-1", false);
        }
    }

    function refreshWindowIcons() {
        if (Quickshell.env("DISPLAY") !== null && !windowIconsProcess.running)
            windowIconsProcess.running = true;
    }

    Process {
        id: windowIconsProcess
        command: ["turtl-window-icons"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windowIcons = JSON.parse(text);
                } catch (_) {
                    root.windowIcons = ({});
                }
            }
        }
    }

    function pollNiri() {
        if (!isNiri)
            return;
        refreshWindowIcons();
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
        running: root.isNiri && Shell.SessionTools.has("niri")
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
                id: workspaceBubble
                required property int modelData
                readonly property bool active: root.focused(modelData)
                readonly property var icons: {
                    root.hyprlandToplevelRevision;
                    root.desktopEntriesRevision;
                    return root.iconsFor(modelData);
                }
                readonly property var hyprlandWorkspace: {
                    root.hyprlandToplevelRevision;
                    return Hyprland.workspaces.values.find(candidate => candidate.id === workspaceBubble.modelData) ?? null;
                }

                width: Math.max(22, content.implicitWidth + 16)
                height: Shell.Theme.widgetHeight
                hovered: mouse.containsMouse
                background: workspaceBubble.active ? Shell.Theme.lavender : Shell.Theme.bubbleBackground
                accent: workspaceBubble.active ? Shell.Theme.lavender : Shell.Theme.bubbleHover

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 4

                    Item {
                        width: workspaceNumber.implicitWidth
                        height: Shell.Theme.widgetHeight

                        Primitives.ThemeText {
                            id: workspaceNumber
                            anchors.centerIn: parent
                            text: workspaceBubble.modelData < 0 ? (workspaceBubble.hyprlandWorkspace?.name ?? workspaceBubble.modelData) : workspaceBubble.modelData
                            color: workspaceBubble.active ? Shell.Theme.base : (workspaceBubble.icons.length ? Shell.Theme.text : Shell.Theme.overlay1)
                            font.bold: workspaceBubble.active
                        }
                    }

                    Repeater {
                        model: workspaceBubble.icons

                        delegate: Item {
                            required property string modelData
                            width: 16
                            height: Shell.Theme.widgetHeight

                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: modelData
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                        }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: root.activate(workspaceBubble.modelData)
                    onWheel: wheel => root.scroll(wheel.angleDelta.y)
                }

                WorkspacePreview {
                    target: mouse
                    workspace: workspaceBubble.hyprlandWorkspace
                    hovered: !root.isNiri && mouse.containsMouse
                    revision: root.hyprlandToplevelRevision
                    iconResolver: toplevel => root.iconFor({
                            identifiers: [toplevel.handle?.appId ?? "", toplevel.lastIpcObject?.["class"] ?? ""],
                            pid: toplevel.lastIpcObject?.pid
                        })
                }

                Shell.BarTooltip {
                    target: mouse
                    text: "Workspace " + workspaceBubble.modelData
                    hovered: root.isNiri && mouse.containsMouse
                }
            }
        }
    }
}
