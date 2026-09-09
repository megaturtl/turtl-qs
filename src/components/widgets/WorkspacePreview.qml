import QtQuick
import Quickshell
import ".." as Shell

PopupWindow {
    id: root

    property Item target: null
    property var workspace: null
    property bool hovered: false
    property int revision: 0

    property real canvasWidth: 224
    property bool hasMonitorGeometry: workspace?.monitor?.width > 0 && workspace?.monitor?.height > 0
    property int monitorTransform: workspace?.monitor?.lastIpcObject?.transform ?? 0
    property bool monitorRotated: monitorTransform === 1 || monitorTransform === 3
    property real monitorX: hasMonitorGeometry ? workspace.monitor.x : 0
    property real monitorY: hasMonitorGeometry ? workspace.monitor.y : 0
    property real monitorWidth: hasMonitorGeometry ? (monitorRotated ? workspace.monitor.height : workspace.monitor.width) / Math.max(1, workspace.monitor.scale) : 1920
    property real monitorHeight: hasMonitorGeometry ? (monitorRotated ? workspace.monitor.width : workspace.monitor.height) / Math.max(1, workspace.monitor.scale) : 1080
    color: "transparent"

    mask: Region {
        width: 0
        height: 0
    }

    implicitWidth: workspaceCanvas.width + 16
    implicitHeight: workspaceCanvas.height + 16

    anchor.item: target
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.All

    function workspaceToplevels() {
        root.revision;
        return root.workspace?.toplevels?.values ?? [];
    }

    function desktopEntryFor(toplevel) {
        const identifiers = [toplevel.handle?.appId ?? "", toplevel.lastIpcObject?.["class"] ?? ""];
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

    function iconFor(toplevel) {
        const iconName = desktopEntryFor(toplevel)?.icon ?? "";
        return iconName && Quickshell.hasThemeIcon(iconName) ? iconName : "";
    }

    function titleFor(toplevel) {
        return toplevel.title || desktopEntryFor(toplevel)?.name || toplevel.lastIpcObject?.["class"] || toplevel.handle?.appId || "Untitled window";
    }

    function scheduleAnchorUpdate() {
        if (visible)
            anchorUpdateTimer.restart();
    }

    function updateVisibility() {
        if (!hovered || workspaceToplevels().length === 0) {
            showTimer.stop();
            visible = false;
            return;
        }

        if (!visible)
            showTimer.restart();
    }

    onHoveredChanged: updateVisibility()
    onWorkspaceChanged: updateVisibility()
    onRevisionChanged: updateVisibility()
    onTargetChanged: {
        showTimer.stop();
        visible = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: Shell.Theme.bubbleRadius
        color: Shell.Theme.mantle
        border.color: Shell.Theme.bubbleBorder
        border.width: 1

        Item {
            id: workspaceCanvas
            anchors.centerIn: parent
            width: root.canvasWidth
            height: width * root.monitorHeight / root.monitorWidth
            clip: true

            Repeater {
                model: root.workspaceToplevels()

                delegate: Rectangle {
                    id: windowPreview
                    required property var modelData

                    property var toplevelIpc: modelData.lastIpcObject
                    property var toplevelAt: toplevelIpc?.at ?? []
                    property var toplevelSize: toplevelIpc?.size ?? []
                    property real sourceX: toplevelAt.length > 0 ? toplevelAt[0] : root.monitorX
                    property real sourceY: toplevelAt.length > 1 ? toplevelAt[1] : root.monitorY
                    property real sourceWidth: toplevelSize.length > 0 ? toplevelSize[0] : 0
                    property real sourceHeight: toplevelSize.length > 1 ? toplevelSize[1] : 0

                    x: (sourceX - root.monitorX) * workspaceCanvas.width / root.monitorWidth
                    y: (sourceY - root.monitorY) * workspaceCanvas.height / root.monitorHeight
                    width: sourceWidth * workspaceCanvas.width / root.monitorWidth
                    height: sourceHeight * workspaceCanvas.height / root.monitorHeight
                    visible: sourceWidth > 0 && sourceHeight > 0
                    radius: Shell.Theme.bubbleRadius - 2
                    color: Shell.Theme.surface0
                    clip: true

                    Image {
                        property string iconName: root.iconFor(windowPreview.modelData)

                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        visible: iconName.length > 0
                        source: iconName ? Quickshell.iconPath(iconName) : ""
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: title.implicitHeight + 8
                        color: Shell.Theme.withAlpha(Shell.Theme.mantle, 0.88)

                        Text {
                            id: title
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 6
                            text: root.titleFor(windowPreview.modelData)
                            color: Shell.Theme.text
                            font.family: Shell.Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: anchorUpdateTimer
        interval: 0
        onTriggered: {
            if (root.visible)
                root.anchor.updateAnchor();
        }
    }

    Connections {
        target: root.target

        function onXChanged() {
            root.scheduleAnchorUpdate();
        }

        function onYChanged() {
            root.scheduleAnchorUpdate();
        }

        function onWidthChanged() {
            root.scheduleAnchorUpdate();
        }

        function onHeightChanged() {
            root.scheduleAnchorUpdate();
        }
    }

    Timer {
        id: showTimer
        interval: Shell.Theme.tooltipDelay
        onTriggered: {
            if (root.hovered && root.workspaceToplevels().length > 0)
                root.visible = true;
        }
    }
}
