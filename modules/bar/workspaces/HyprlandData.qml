pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var monitors: []
    property var workspaceOccupationMap: ({})
    property var workspaceWindowsMap: ({})

    // Debounce timer to batch rapid Hyprland events
    Timer {
        id: updateDebounce
        interval: 100
        onTriggered: {
            getClients.running = true
            getMonitors.running = true
        }
    }

    function updateWindowList() {
        updateDebounce.restart()
    }

    function getMonitorDataById(monitorId) {
        for (let i = 0; i < root.monitors.length; i++) {
            if (root.monitors[i].id === monitorId)
                return root.monitors[i]
        }
        return null
    }

    function getVisibleWorkspaceIdsForMonitor(monitorLike) {
        if (!monitorLike)
            return []

        const monitorId = monitorLike.id
        const monitorData = getMonitorDataById(monitorId) || monitorLike
        const ids = []

        const activeWorkspaceId = monitorData?.activeWorkspace?.id
        if (typeof activeWorkspaceId === "number")
            ids.push(activeWorkspaceId)

        const specialWorkspaceId = monitorData?.specialWorkspace?.id
        if (typeof specialWorkspaceId === "number" && specialWorkspaceId !== 0)
            ids.push(specialWorkspaceId)

        return ids
    }

    function isWindowVisibleOnMonitor(windowData, monitorLike) {
        if (!windowData || !monitorLike)
            return false

        const visibleWorkspaceIds = getVisibleWorkspaceIdsForMonitor(monitorLike)
        return windowData.monitor === monitorLike.id && visibleWorkspaceIds.includes(windowData?.workspace?.id)
    }

    function monitorHasFullscreenWindow(monitorLike) {
        if (!monitorLike)
            return false

        const toplevel = ToplevelManager.activeToplevel
        if (toplevel && toplevel.fullscreen && Hyprland.focusedMonitor?.id === monitorLike.id)
            return true

        for (let i = 0; i < root.windowList.length; i++) {
            const windowData = root.windowList[i]
            if (windowData.fullscreen && isWindowVisibleOnMonitor(windowData, monitorLike))
                return true
        }

        return false
    }

    function monitorHasVisibleTiledWindows(monitorLike) {
        if (!monitorLike)
            return false

        for (let i = 0; i < root.windowList.length; i++) {
            const windowData = root.windowList[i]
            if (!windowData.floating && isWindowVisibleOnMonitor(windowData, monitorLike))
                return true
        }

        return false
    }

    function updateMaps() {
        let occupationMap = {}
        let windowsMap = {}
        for (var i = 0; i < root.windowList.length; ++i) {
            var win = root.windowList[i]
            let wsId = win.workspace.id
            occupationMap[wsId] = true
            if (!windowsMap[wsId]) {
                windowsMap[wsId] = []
            }
            windowsMap[wsId].push(win)
        }
        root.workspaceOccupationMap = occupationMap
        root.workspaceWindowsMap = windowsMap
    }

    Component.onCompleted: {
        updateWindowList()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activespecial") {
                getMonitors.running = true
                return
            }

            // Only request full update for critical events
            let ignoreList = [
                "activewindow", "focusedmon", "monitoradded", 
                "createworkspace", "destroyworkspace", "moveworkspace", 
                "movewindow", "windowtitle"
            ]
            if (ignoreList.includes(event.name)) return
            updateWindowList()
        }
    }

    Process {
        id: getClients
        command: ["bash", "-c", "hyprctl clients -j | jq -c"]
        stdout: SplitParser {
            onRead: (data) => {
                root.windowList = JSON.parse(data)
                let tempWinByAddress = {}
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i]
                    tempWinByAddress[win.address] = win
                }
                root.windowByAddress = tempWinByAddress
                root.addresses = root.windowList.map((win) => win.address)
                updateMaps()
            }
        }
    }
    Process {
        id: getMonitors
        command: ["bash", "-c", "hyprctl monitors -j | jq -c"]
        stdout: SplitParser {
            onRead: (data) => {
                root.monitors = JSON.parse(data)
            }
        }
    }
}
