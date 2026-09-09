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
                        identifiers: [window.app_id ?? ""]
                    }));
        }

        const workspace = Hyprland.workspaces.values.find(candidate => candidate.id === id);
        return workspace?.toplevels.values.map(window => ({
                    identifiers: [window.handle?.appId ?? "", window.lastIpcObject?.["class"] ?? ""]
                })) ?? [];
    }

    function iconsFor(id) {
        const icons = [];
        for (const client of clientsFor(id)) {
            const icon = desktopEntryFor(client.identifiers)?.icon;
            if (icon && Quickshell.hasThemeIcon(icon) && icons.indexOf(icon) === -1)
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
                            text: workspaceBubble.modelData
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
                                source: Quickshell.iconPath(modelData)
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
