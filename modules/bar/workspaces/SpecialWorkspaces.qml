import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    required property var bar
    required property string orientation

    property real radius: Styling.radius(0)
    property real innerRadius: radius
    property real startRadius: radius
    property real endRadius: radius
    property bool enableShadow: Config.showBackground
    property int baseSize: 36
    property int pillSpacing: 4
    property int maxVisibleIcons: 3
    property int iconSize: Math.round(baseSize * 0.6)

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar.screen)
    readonly property int monitorId: monitor?.id ?? -1
    readonly property string displayMode: Config.bar?.specialWorkspacesDisplay ?? "icons"

    function isSpecialWorkspaceName(name) {
        return typeof name === "string" && (name === "special" || name.startsWith("special:"));
    }

    function formatWorkspaceName(name) {
        if (name === "special")
            return "special";
        if (typeof name === "string" && name.startsWith("special:"))
            return name.slice(8);
        return name || "special";
    }

    function workspaceArgument(name) {
        if (name === "special" || name === "special:")
            return "";
        if (typeof name === "string" && name.startsWith("special:"))
            return name.slice(8);
        return name || "";
    }

    function toggleWorkspace(name) {
        const argument = workspaceArgument(name);
        Hyprland.dispatch(argument !== "" ? `togglespecialworkspace ${argument}` : "togglespecialworkspace");
    }

    function getWorkspaceIconSource(windowData) {
        return Quickshell.iconPath(AppSearch.getCachedIcon(windowData?.class), "image-missing");
    }

    function getNamePillWidth(label) {
        const textWidth = Math.round((label || "").length * (Styling.fontSize(-1) * 0.62));
        return Math.max(baseSize, textWidth + 24);
    }

    function getIconPillWidth(workspaceData) {
        const iconCount = Math.min(maxVisibleIcons, workspaceData?.visibleWindows?.length ?? 0);
        const hiddenCount = workspaceData?.hiddenWindowCount ?? 0;
        const hiddenCountWidth = hiddenCount > 0 ? Math.max(12, String(hiddenCount).length * 7 + 8) : 0;
        return Math.max(baseSize, iconCount * iconSize + Math.max(0, iconCount - 1) * 2 + hiddenCountWidth + 16);
    }

    readonly property var monitorData: {
        const monitors = HyprlandData.monitors;
        for (let i = 0; i < monitors.length; i++) {
            if (monitors[i].id === monitorId)
                return monitors[i];
        }
        return null;
    }

    readonly property string activeSpecialWorkspace: {
        const specialWorkspace = monitorData?.specialWorkspace;
        return specialWorkspace?.name || "";
    }

    readonly property var specialWorkspaces: {
        const grouped = {};
        const windows = HyprlandData.windowList;

        for (let i = 0; i < windows.length; i++) {
            const windowData = windows[i];
            const workspaceName = windowData?.workspace?.name || "";

            if (windowData?.monitor !== monitorId || !isSpecialWorkspaceName(workspaceName))
                continue;

            if (!grouped[workspaceName]) {
                grouped[workspaceName] = {
                    name: workspaceName,
                    label: formatWorkspaceName(workspaceName),
                    windows: []
                };
            }

            grouped[workspaceName].windows.push(windowData);
        }

        const workspaces = Object.values(grouped);
        workspaces.sort((left, right) => left.label.localeCompare(right.label));

        for (let i = 0; i < workspaces.length; i++) {
            const windowsForWorkspace = workspaces[i].windows.slice().sort((left, right) => {
                const leftFocus = left?.focusHistoryID ?? Number.MAX_SAFE_INTEGER;
                const rightFocus = right?.focusHistoryID ?? Number.MAX_SAFE_INTEGER;
                return leftFocus - rightFocus;
            });

            workspaces[i].windows = windowsForWorkspace;
            workspaces[i].visibleWindows = windowsForWorkspace.slice(0, maxVisibleIcons);
            workspaces[i].hiddenWindowCount = Math.max(0, windowsForWorkspace.length - maxVisibleIcons);
            workspaces[i].isActive = workspaces[i].name === activeSpecialWorkspace;
        }

        return workspaces;
    }

    readonly property bool hasSpecialWorkspaces: (Config.bar?.showSpecialWorkspaces ?? true) && specialWorkspaces.length > 0

    visible: hasSpecialWorkspaces
    implicitWidth: orientation === "horizontal" ? specialRow.implicitWidth : specialColumn.implicitWidth
    implicitHeight: orientation === "vertical" ? specialColumn.implicitHeight : specialRow.implicitHeight

    Row {
        id: specialRow
        visible: root.orientation === "horizontal"
        spacing: root.pillSpacing

        Repeater {
            model: root.specialWorkspaces

            Button {
                id: specialButton

                required property int index
                required property var modelData

                readonly property bool isActive: modelData.isActive
                readonly property bool isFirst: index === 0
                readonly property bool isLast: index === root.specialWorkspaces.length - 1
                readonly property real pillStartRadius: isFirst ? root.startRadius : root.innerRadius
                readonly property real pillEndRadius: isLast ? root.endRadius : root.innerRadius

                implicitHeight: root.baseSize
                implicitWidth: root.displayMode === "names" ? root.getNamePillWidth(modelData.label) : root.getIconPillWidth(modelData)

                onClicked: root.toggleWorkspace(modelData.name)

                background: StyledRect {
                    id: specialButtonBg
                    variant: specialButton.isActive ? "primary" : "bg"
                    enableShadow: root.enableShadow
                    topLeftRadius: specialButton.pillStartRadius
                    bottomLeftRadius: specialButton.pillStartRadius
                    topRightRadius: specialButton.pillEndRadius
                    bottomRightRadius: specialButton.pillEndRadius

                    Rectangle {
                        anchors.fill: parent
                        color: Styling.srItem("overprimary")
                        opacity: specialButton.pressed ? 0.18 : (specialButton.hovered ? 0.1 : 0)
                        radius: parent.radius ?? 0

                        Behavior on opacity {
                            enabled: (Config.animDuration ?? 0) > 0
                            NumberAnimation {
                                duration: (Config.animDuration ?? 0) / 2
                            }
                        }
                    }
                }

                contentItem: Loader {
                    sourceComponent: root.displayMode === "names" ? labelContent : iconContent
                }

                StyledToolTip {
                    show: specialButton.hovered
                    tooltipText: `${modelData.label} (${modelData.windows.length})`
                }

                Component {
                    id: labelContent

                    Text {
                        id: labelText
                        text: specialButton.modelData.label
                        color: specialButtonBg.item
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                Component {
                    id: iconContent

                    Item {
                        anchors.fill: parent

                        Row {
                            id: iconsRow
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: specialButton.modelData.visibleWindows

                                Item {
                                    required property var modelData
                                    width: root.iconSize
                                    height: root.iconSize

                                    IconImage {
                                        id: workspaceIcon
                                        anchors.fill: parent
                                        source: root.getWorkspaceIconSource(modelData)
                                        implicitSize: root.iconSize
                                    }

                                    Tinted {
                                        sourceItem: workspaceIcon
                                        anchors.fill: workspaceIcon
                                    }
                                }
                            }

                            Text {
                                visible: specialButton.modelData.hiddenWindowCount > 0
                                text: `+${specialButton.modelData.hiddenWindowCount}`
                                color: specialButtonBg.item
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }

    Column {
        id: specialColumn
        visible: root.orientation === "vertical"
        spacing: root.pillSpacing

        Repeater {
            model: root.specialWorkspaces

            Button {
                id: specialButtonVertical

                required property int index
                required property var modelData

                readonly property bool isActive: modelData.isActive
                readonly property bool isFirst: index === 0
                readonly property bool isLast: index === root.specialWorkspaces.length - 1
                readonly property real pillStartRadius: isFirst ? root.startRadius : root.innerRadius
                readonly property real pillEndRadius: isLast ? root.endRadius : root.innerRadius

                implicitHeight: root.baseSize
                implicitWidth: root.displayMode === "names" ? root.getNamePillWidth(modelData.label) : root.getIconPillWidth(modelData)

                onClicked: root.toggleWorkspace(modelData.name)

                background: StyledRect {
                    id: specialButtonVerticalBg
                    variant: specialButtonVertical.isActive ? "primary" : "bg"
                    enableShadow: root.enableShadow
                    topLeftRadius: specialButtonVertical.pillStartRadius
                    topRightRadius: specialButtonVertical.pillStartRadius
                    bottomLeftRadius: specialButtonVertical.pillEndRadius
                    bottomRightRadius: specialButtonVertical.pillEndRadius

                    Rectangle {
                        anchors.fill: parent
                        color: Styling.srItem("overprimary")
                        opacity: specialButtonVertical.pressed ? 0.18 : (specialButtonVertical.hovered ? 0.1 : 0)
                        radius: parent.radius ?? 0

                        Behavior on opacity {
                            enabled: (Config.animDuration ?? 0) > 0
                            NumberAnimation {
                                duration: (Config.animDuration ?? 0) / 2
                            }
                        }
                    }
                }

                contentItem: Loader {
                    sourceComponent: root.displayMode === "names" ? labelContentVertical : iconContentVertical
                }

                StyledToolTip {
                    show: specialButtonVertical.hovered
                    tooltipText: `${modelData.label} (${modelData.windows.length})`
                }

                Component {
                    id: labelContentVertical

                    Text {
                        id: labelTextVertical
                        text: specialButtonVertical.modelData.label
                        color: specialButtonVerticalBg.item
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                Component {
                    id: iconContentVertical

                    Item {
                        anchors.fill: parent

                        Row {
                            id: iconsRowVertical
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: specialButtonVertical.modelData.visibleWindows

                                Item {
                                    required property var modelData
                                    width: root.iconSize
                                    height: root.iconSize

                                    IconImage {
                                        id: workspaceIconVertical
                                        anchors.fill: parent
                                        source: root.getWorkspaceIconSource(modelData)
                                        implicitSize: root.iconSize
                                    }

                                    Tinted {
                                        sourceItem: workspaceIconVertical
                                        anchors.fill: workspaceIconVertical
                                    }
                                }
                            }

                            Text {
                                visible: specialButtonVertical.modelData.hiddenWindowCount > 0
                                text: `+${specialButtonVertical.modelData.hiddenWindowCount}`
                                color: specialButtonVerticalBg.item
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.weight: Font.Medium
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
