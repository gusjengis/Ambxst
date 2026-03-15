import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.modules.bar.workspaces // For HyprlandData

PanelWindow {
    id: screenCorners

    readonly property var monitor: Hyprland.monitorFor(screen);

    // Fullscreen detection
    readonly property bool activeWindowFullscreen: HyprlandData.monitorHasFullscreenWindow(monitor)

    visible: Config.theme.enableCorners && Config.roundness > 0 && !activeWindowFullscreen

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "ambxst:screenCorners"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {
        item: null
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    ScreenCornersContent {
        id: cornersContent
        anchors.fill: parent
        hasFullscreenWindow: screenCorners.activeWindowFullscreen
    }
}
