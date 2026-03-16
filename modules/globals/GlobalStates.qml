pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.services
import qs.config

Singleton {
    id: root

    property var wallpaperManager: null
    property string avatarCacheBuster: ""

    function pickUserAvatar() {
        filePickerProcess.running = true;
    }

    Process {
        id: filePickerProcess
        running: false
        command: ["zenity", "--file-selection", "--title=Select User Icon", "--file-filter=Images | *.png *.jpg *.jpeg *.svg *.webp"]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path) {
                    console.log("Selected icon:", path);
                    copyIconProcess.command = ["cp", path, Quickshell.env("HOME") + "/.face.icon"];
                    copyIconProcess.running = true;
                }
            }
        }
    }

    Process {
        id: copyIconProcess
        running: false
        command: []

        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("Icon updated successfully");
                avatarCacheBuster = Date.now();
            } else {
                console.warn("Failed to update icon");
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // HYPRLAND LAYOUT STATE (dynamic, not persisted)
    // ═══════════════════════════════════════════════════════════════
    property string hyprlandLayout: "dwindle"
    property bool hyprlandLayoutReady: false
    readonly property var availableLayouts: ["dwindle", "master", "scrolling"]
    property int hyprlandBorderSizeLive: 2
    property bool hyprlandBorderSizeReady: false
    property int hyprlandRoundingLive: 16
    property bool hyprlandRoundingReady: false
    property int hyprlandGapsInLive: 2
    property bool hyprlandGapsInReady: false
    property var hyprlandGapsOutLive: ({
        top: 4,
        right: 4,
        bottom: 4,
        left: 4,
        raw: "4"
    })
    property bool hyprlandGapsOutReady: false

    function setHyprlandLayout(layout) {
        if (availableLayouts.includes(layout)) {
            hyprlandLayout = layout;
        }
    }

    function cycleHyprlandLayout() {
        const currentIndex = availableLayouts.indexOf(hyprlandLayout);
        const nextIndex = (currentIndex + 1) % availableLayouts.length;
        hyprlandLayout = availableLayouts[nextIndex];
    }

    function _expandGapsOutValues(rawValue) {
        var tokens = [];

        if (typeof rawValue === "number") {
            tokens = [rawValue];
        } else if (typeof rawValue === "string") {
            var matches = rawValue.match(/-?\d+/g);
            tokens = matches ? matches.map(Number) : [];
        } else if (rawValue !== null && rawValue !== undefined) {
            tokens = [Number(rawValue)];
        }

        tokens = tokens.filter(function(value) {
            return !isNaN(value);
        });

        if (tokens.length === 0) {
            tokens = [Config.hyprland?.gapsOut ?? 4];
        }

        if (tokens.length === 1) {
            tokens = [tokens[0], tokens[0], tokens[0], tokens[0]];
        } else if (tokens.length === 2) {
            tokens = [tokens[0], tokens[1], tokens[0], tokens[1]];
        } else if (tokens.length === 3) {
            tokens = [tokens[0], tokens[1], tokens[2], tokens[1]];
        } else {
            tokens = tokens.slice(0, 4);
        }

        return {
            top: tokens[0],
            right: tokens[1],
            bottom: tokens[2],
            left: tokens[3],
            raw: tokens.join(" ")
        };
    }

    function updateHyprlandGapsOutLive(rawValue) {
        hyprlandGapsOutLive = _expandGapsOutValues(rawValue);
        hyprlandGapsOutReady = true;
    }

    function _normalizeHyprlandInt(rawValue, fallback) {
        const parsed = Number(rawValue);
        return isNaN(parsed) ? fallback : parsed;
    }

    function _extractHyprlandOptionValue(parsed) {
        return parsed.custom ?? parsed.str ?? parsed.int;
    }

    function updateHyprlandBorderSizeLive(rawValue) {
        hyprlandBorderSizeLive = _normalizeHyprlandInt(rawValue, Config.hyprland?.borderSize ?? 2);
        hyprlandBorderSizeReady = true;
    }

    function updateHyprlandRoundingLive(rawValue) {
        hyprlandRoundingLive = _normalizeHyprlandInt(rawValue, Config.hyprland?.rounding ?? 16);
        hyprlandRoundingReady = true;
    }

    function updateHyprlandGapsInLive(rawValue) {
        hyprlandGapsInLive = _normalizeHyprlandInt(rawValue, Config.hyprland?.gapsIn ?? 2);
        hyprlandGapsInReady = true;
    }

    function updateHyprlandLayoutLive(rawValue) {
        if (typeof rawValue === "string" && availableLayouts.includes(rawValue)) {
            hyprlandLayout = rawValue;
        } else {
            hyprlandLayout = Config.hyprland?.layout ?? "dwindle";
        }
        hyprlandLayoutReady = true;
    }

    function refreshHyprlandBorderSize() {
        borderSizeQueryProcess.running = false;
        borderSizeQueryProcess.command = ["hyprctl", "getoption", "general:border_size", "-j"];
        borderSizeQueryProcess.running = true;
    }

    function refreshHyprlandRounding() {
        roundingQueryProcess.running = false;
        roundingQueryProcess.command = ["hyprctl", "getoption", "decoration:rounding", "-j"];
        roundingQueryProcess.running = true;
    }

    function refreshHyprlandGapsIn() {
        gapsInQueryProcess.running = false;
        gapsInQueryProcess.command = ["hyprctl", "getoption", "general:gaps_in", "-j"];
        gapsInQueryProcess.running = true;
    }

    function refreshHyprlandGapsOut() {
        gapsOutQueryProcess.running = false;
        gapsOutQueryProcess.command = ["hyprctl", "getoption", "general:gaps_out", "-j"];
        gapsOutQueryProcess.running = true;
    }

    function refreshHyprlandLayout() {
        layoutQueryProcess.running = false;
        layoutQueryProcess.command = ["hyprctl", "getoption", "general:layout", "-j"];
        layoutQueryProcess.running = true;
    }

    function refreshManagedHyprlandValues() {
        refreshHyprlandBorderSize();
        refreshHyprlandRounding();
        refreshHyprlandGapsIn();
        refreshHyprlandGapsOut();
        refreshHyprlandLayout();
    }

    function getEffectiveHyprlandBorderSize() {
        return (Config.hyprland?.manageBorderSize ?? true) ? (Config.hyprland?.borderSize ?? 2) : hyprlandBorderSizeLive;
    }

    function getEffectiveHyprlandRounding() {
        return (Config.hyprland?.manageRounding ?? true) ? (Config.hyprland?.rounding ?? 16) : hyprlandRoundingLive;
    }

    function getEffectiveHyprlandGapsIn() {
        return (Config.hyprland?.manageGapsIn ?? true) ? (Config.hyprland?.gapsIn ?? 2) : hyprlandGapsInLive;
    }

    function getEffectiveHyprlandLayout() {
        return (Config.hyprland?.manageLayout ?? true) ? (Config.hyprland?.layout ?? "dwindle") : hyprlandLayout;
    }

    function getEffectiveHyprlandGapsOut(side) {
        const managedByAmbxst = Config.hyprland?.manageGapsOut ?? true;
        const source = managedByAmbxst ? _expandGapsOutValues(Config.hyprland?.gapsOut ?? 4) : hyprlandGapsOutLive;
        return source[side] ?? source.top ?? (Config.hyprland?.gapsOut ?? 4);
    }

    // Query current layout from Hyprland on startup
    Process {
        id: layoutQueryProcess
        command: ["hyprctl", "getoption", "general:layout", "-j"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data);
                    const rawValue = root._extractHyprlandOptionValue(parsed);
                    root.updateHyprlandLayoutLive(rawValue);
                    console.log("GlobalStates: Layout inicial desde Hyprland: " + root.hyprlandLayout);
                } catch (e) {
                    console.warn("GlobalStates: Error parsing layout from hyprctl: " + e);
                }
            }
        }
        onExited: {
            if (!root.hyprlandLayoutReady) {
                root.updateHyprlandLayoutLive(Config.hyprland?.layout ?? "dwindle");
            }
        }
    }

    Process {
        id: borderSizeQueryProcess
        running: true
        command: ["hyprctl", "getoption", "general:border_size", "-j"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data);
                    root.updateHyprlandBorderSizeLive(root._extractHyprlandOptionValue(parsed));
                } catch (e) {
                    console.warn("GlobalStates: Error parsing border_size from hyprctl: " + e);
                }
            }
        }

        onExited: {
            if (!root.hyprlandBorderSizeReady) {
                root.updateHyprlandBorderSizeLive(Config.hyprland?.borderSize ?? 2);
            }
        }
    }

    Process {
        id: roundingQueryProcess
        running: true
        command: ["hyprctl", "getoption", "decoration:rounding", "-j"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data);
                    root.updateHyprlandRoundingLive(root._extractHyprlandOptionValue(parsed));
                } catch (e) {
                    console.warn("GlobalStates: Error parsing rounding from hyprctl: " + e);
                }
            }
        }

        onExited: {
            if (!root.hyprlandRoundingReady) {
                root.updateHyprlandRoundingLive(Config.hyprland?.rounding ?? 16);
            }
        }
    }

    Process {
        id: gapsInQueryProcess
        running: true
        command: ["hyprctl", "getoption", "general:gaps_in", "-j"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data);
                    root.updateHyprlandGapsInLive(root._extractHyprlandOptionValue(parsed));
                } catch (e) {
                    console.warn("GlobalStates: Error parsing gaps_in from hyprctl: " + e);
                }
            }
        }

        onExited: {
            if (!root.hyprlandGapsInReady) {
                root.updateHyprlandGapsInLive(Config.hyprland?.gapsIn ?? 2);
            }
        }
    }

    Process {
        id: gapsOutQueryProcess
        running: true
        command: ["hyprctl", "getoption", "general:gaps_out", "-j"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data);
                    const rawValue = root._extractHyprlandOptionValue(parsed);
                    root.updateHyprlandGapsOutLive(rawValue);
                    console.log("GlobalStates: Gaps out inicial desde Hyprland: " + root.hyprlandGapsOutLive.raw);
                } catch (e) {
                    console.warn("GlobalStates: Error parsing gaps_out from hyprctl: " + e);
                }
            }
        }

        onExited: {
            if (!root.hyprlandGapsOutReady) {
                root.updateHyprlandGapsOutLive(Config.hyprland?.gapsOut ?? 4);
            }
        }
    }

    // Ensure LockscreenService singleton is loaded
    Component.onCompleted: {
        // Reference the singleton to ensure it loads
        LockscreenService.toString();
    }

    // Persistent launcher state across monitors
    property string launcherSearchText: ""
    property int launcherSelectedIndex: -1
    property int launcherCurrentTab: 0

    function clearLauncherState() {
        launcherSearchText = "";
        launcherSelectedIndex = -1;
    }

    // Persistent dashboard state across monitors  
    property int dashboardCurrentTab: 0
    
    // Widgets tab internal state (for prefix-based tabs)
    // 0=launcher, 1=clipboard, 2=emoji, 3=tmux, 4=wallpapers
    property int widgetsTabCurrentIndex: 0

    // Persistent wallpaper navigation state
    property int wallpaperSelectedIndex: -1

    function clearWallpaperState() {
        wallpaperSelectedIndex = -1;
    }

    function getNotchOpen(screenName) {
        let visibilities = Visibilities.getForScreen(screenName);
        return visibilities.launcher || visibilities.dashboard || visibilities.overview || visibilities.presets;
    }

    function getActiveLauncher() {
        let active = Visibilities.getForActive();
        return active ? active.launcher : false;
    }

    function getActiveDashboard() {
        let active = Visibilities.getForActive();
        return active ? active.dashboard : false;
    }

    function getActiveOverview() {
        let active = Visibilities.getForActive();
        return active ? active.overview : false;
    }

    function getActivePresets() {
        let active = Visibilities.getForActive();
        return active ? active.presets : false;
    }

    function getActiveNotchOpen() {
        let active = Visibilities.getForActive();
        return active ? (active.launcher || active.dashboard || active.overview) : false;
    }

    // Legacy properties for backward compatibility - use active screen
    readonly property bool notchOpen: getActiveNotchOpen()
    readonly property bool overviewOpen: getActiveOverview()
    readonly property bool presetsOpen: getActivePresets()
    readonly property bool launcherOpen: getActiveLauncher()
    readonly property bool dashboardOpen: getActiveDashboard()

    // Lockscreen state
    property bool lockscreenVisible: false

    // OSD state
    property bool osdVisible: false
    property string osdIndicator: "volume" // volume, mic, brightness

    // Screenshot Tool state
    property bool screenshotToolVisible: false
    // property string screenshotToolMode: "normal" // DEPRECATED
    property string screenshotCaptureMode: "region" // region, window, screen
    
    // Global selection state for synchronization
    property int screenshotSelectionX: 0
    property int screenshotSelectionY: 0
    property int screenshotSelectionW: 0
    property int screenshotSelectionH: 0

    // Screen Record Tool state
    property bool screenRecordToolVisible: false

    // Mirror Tool state
    property bool mirrorWindowVisible: false

    // Settings Window state
    property bool settingsWindowVisible: false

    // Theme editor state - persists across tab switches
    property bool themeHasChanges: false
    property var themeSnapshot: null

    // Constants for theme snapshot operations (avoid duplication)
    // Get SR variant names dynamically from Config.theme
    function _getSrVariantNames() {
        var names = [];
        var keys = Object.keys(Config.theme);
        for (var i = 0; i < keys.length; i++) {
            if (keys[i].startsWith("sr")) {
                names.push(keys[i]);
            }
        }
        return names;
    }

    readonly property var _simpleThemeProps: [
        "roundness", "oledMode", "lightMode", "font", "fontSize", "monoFont", "monoFontSize",
        "tintIcons", "enableCorners", "animDuration",
        "shadowOpacity", "shadowColor", "shadowXOffset", "shadowYOffset", "shadowBlur"
    ]
    readonly property var _srVariantProps: [
        "gradientType", "gradientAngle", "gradientCenterX", "gradientCenterY",
        "halftoneDotMin", "halftoneDotMax", "halftoneStart", "halftoneEnd",
        "halftoneDotColor", "halftoneBackgroundColor", "itemColor", "opacity"
    ]

    // Deep copy a single SR variant
    function _copySrVariant(src) {
        var copy = {};
        for (var i = 0; i < _srVariantProps.length; i++) {
            if (src[_srVariantProps[i]] !== undefined) {
                copy[_srVariantProps[i]] = src[_srVariantProps[i]];
            }
        }
        // Deep copy arrays with safety checks
        try {
            copy.gradient = (src.gradient !== undefined) ? JSON.parse(JSON.stringify(src.gradient)) : [];
        } catch (e) {
            console.warn("GlobalStates: Error cloning gradient: " + e);
            copy.gradient = [];
        }
        
        try {
            copy.border = (src.border !== undefined) ? JSON.parse(JSON.stringify(src.border)) : [];
        } catch (e) {
            console.warn("GlobalStates: Error cloning border: " + e);
            copy.border = [];
        }
        
        return copy;
    }

    // Restore a single SR variant from source to destination
    function _restoreSrVariant(src, dest) {
        for (var i = 0; i < _srVariantProps.length; i++) {
            if (src[_srVariantProps[i]] !== undefined) {
                dest[_srVariantProps[i]] = src[_srVariantProps[i]];
            }
        }
        // Deep copy arrays with safety checks
        if (src.gradient !== undefined) {
            try {
                dest.gradient = JSON.parse(JSON.stringify(src.gradient));
            } catch (e) { console.warn("GlobalStates: Error restoring gradient: " + e); }
        }
        
        if (src.border !== undefined) {
            try {
                dest.border = JSON.parse(JSON.stringify(src.border));
            } catch (e) { console.warn("GlobalStates: Error restoring border: " + e); }
        }
    }

    // Create a deep copy of the current theme config
    function createThemeSnapshot() {
        var snapshot = {};
        var theme = Config.theme;
        var srVariantNames = _getSrVariantNames();

        // Copy simple properties
        for (var i = 0; i < _simpleThemeProps.length; i++) {
            var prop = _simpleThemeProps[i];
            snapshot[prop] = theme[prop];
        }

        // Copy SR variants
        for (var j = 0; j < srVariantNames.length; j++) {
            var name = srVariantNames[j];
            snapshot[name] = _copySrVariant(theme[name]);
        }

        return snapshot;
    }

    // Restore theme from snapshot
    function restoreThemeSnapshot(snapshot) {
        if (!snapshot) return;

        var theme = Config.theme;
        var srVariantNames = _getSrVariantNames();

        // Restore simple properties
        for (var i = 0; i < _simpleThemeProps.length; i++) {
            var prop = _simpleThemeProps[i];
            theme[prop] = snapshot[prop];
        }

        // Restore SR variants
        for (var j = 0; j < srVariantNames.length; j++) {
            var name = srVariantNames[j];
            if (snapshot[name]) {
                _restoreSrVariant(snapshot[name], theme[name]);
            }
        }
    }

    function markThemeChanged() {
        // Take a snapshot before the first change
        if (!themeHasChanges) {
            themeSnapshot = createThemeSnapshot();
            Config.pauseAutoSave = true;
        }
        themeHasChanges = true;
    }

    function applyThemeChanges() {
        if (themeHasChanges) {
            Config.loader.writeAdapter();
            themeHasChanges = false;
            themeSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardThemeChanges() {
        if (themeHasChanges && themeSnapshot) {
            restoreThemeSnapshot(themeSnapshot);
            themeHasChanges = false;
            themeSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SHELL SETTINGS STATE
    // ═══════════════════════════════════════════════════════════════
    property bool shellHasChanges: false
    property var shellSnapshot: null

    // Shell config sections and their properties
    readonly property var _shellSections: {
        "bar": ["position", "launcherIcon", "launcherIconTint", "launcherIconFullTint", "launcherIconSize", "enableFirefoxPlayer", "screenList", "frameEnabled", "frameThickness", "pinnedOnStartup", "hoverToReveal", "hoverRegionHeight", "showPinButton", "showLayoutButton", "availableOnFullscreen", "pillStyle", "use12hFormat", "containBar", "keepBarShadow", "keepBarBorder"],
        "notch": ["theme", "position", "hoverRegionHeight", "keepHidden"],
        "workspaces": ["shown", "showAppIcons", "alwaysShowNumbers", "showNumbers", "dynamic"],
        "overview": ["rows", "columns", "scale", "workspaceSpacing"],
        "dock": ["enabled", "theme", "position", "height", "iconSize", "spacing", "margin", "hoverRegionHeight", "pinnedOnStartup", "hoverToReveal", "availableOnFullscreen", "showRunningIndicators", "showPinButton", "showOverviewButton", "screenList", "keepHidden"],
        "lockscreen": ["position"],
        "desktop": ["enabled", "iconSize", "spacingVertical", "textColor"],
        "system": ["idle", "ocr"]
    }

    // Create a deep copy of the current shell config
    function createShellSnapshot() {
        var snapshot = {};
        var sections = Object.keys(_shellSections);
        for (var i = 0; i < sections.length; i++) {
            var section = sections[i];
            var props = _shellSections[section];
            snapshot[section] = {};
            for (var j = 0; j < props.length; j++) {
                var prop = props[j];
                var val = Config[section][prop];
                // Deep copy arrays or objects
                if (typeof val === 'object' && val !== null) {
                    snapshot[section][prop] = JSON.parse(JSON.stringify(val));
                } else {
                    snapshot[section][prop] = val;
                }
            }
        }
        return snapshot;
    }

    // Restore shell config from snapshot
    function restoreShellSnapshot(snapshot) {
        if (!snapshot) return;
        var sections = Object.keys(_shellSections);
        for (var i = 0; i < sections.length; i++) {
            var section = sections[i];
            var props = _shellSections[section];
            for (var j = 0; j < props.length; j++) {
                var prop = props[j];
                var val = snapshot[section][prop];
                
                // Special handling for system.idle (JsonObject)
                if (section === "system" && prop === "idle" && val) {
                    if (val.general) {
                        var generalProps = ["lock_cmd", "before_sleep_cmd", "after_sleep_cmd"];
                        for (var k = 0; k < generalProps.length; k++) {
                            var gp = generalProps[k];
                            if (val.general[gp] !== undefined) {
                                Config.system.idle.general[gp] = val.general[gp];
                            }
                        }
                    }
                    if (val.listeners) {
                        Config.system.idle.listeners = JSON.parse(JSON.stringify(val.listeners));
                    }
                }
                // Special handling for system.ocr (JsonObject)
                else if (section === "system" && prop === "ocr" && val) {
                    var keys = Object.keys(val);
                    for (var k = 0; k < keys.length; k++) {
                        var key = keys[k];
                        Config.system.ocr[key] = val[key];
                    }
                }
                // Deep copy arrays or objects
                else if (typeof val === 'object' && val !== null) {
                    Config[section][prop] = JSON.parse(JSON.stringify(val));
                } else {
                    Config[section][prop] = val;
                }
            }
        }
    }

    function markShellChanged() {
        // Take a snapshot before the first change
        if (!shellHasChanges) {
            shellSnapshot = createShellSnapshot();
            Config.pauseAutoSave = true;
        }
        shellHasChanges = true;
    }

    function applyShellChanges() {
        if (shellHasChanges) {
            Config.saveBar();
            Config.saveNotch();
            Config.saveWorkspaces();
            Config.saveOverview();
            Config.saveDock();
            Config.saveLockscreen();
            Config.saveDesktop();
            Config.saveSystem();
            
            shellHasChanges = false;
            shellSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardShellChanges() {
        if (shellHasChanges && shellSnapshot) {
            restoreShellSnapshot(shellSnapshot);
            shellHasChanges = false;
            shellSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // COMPOSITOR SETTINGS STATE
    // ═══════════════════════════════════════════════════════════════
    property bool compositorHasChanges: false
    property var compositorSnapshot: null

    // Compositor config properties (Hyprland)
    readonly property var _compositorProps: [
        "layout", "manageLayout",
        "syncBorderWidth", "borderSize", "manageBorderSize",
        "syncRoundness", "rounding", "manageRounding",
        "gapsIn", "manageGapsIn", "gapsOut", "manageGapsOut",
        "borderAngle", "inactiveBorderAngle",
        "syncBorderColor", "activeBorderColor", "inactiveBorderColor",
        "shadowEnabled", "syncShadowColor", "syncShadowOpacity",
        "shadowRange", "shadowRenderPower", "shadowScale",
        "shadowOpacity", "shadowSharp", "shadowIgnoreWindow",
        "manageBlurEnabled", "blurEnabled", "manageBlurSize", "blurSize",
        "manageBlurPasses", "blurPasses", "manageBlurXray", "blurXray",
        "manageBlurNewOptimizations", "blurNewOptimizations",
        "manageBlurIgnoreOpacity", "blurIgnoreOpacity",
        "manageBlurNoise", "blurNoise", "manageBlurContrast", "blurContrast",
        "manageBlurBrightness", "blurBrightness", "manageBlurVibrancy", "blurVibrancy",
        "manageBlurVibrancyDarkness", "blurVibrancyDarkness",
        "manageBlurSpecial", "blurSpecial", "manageBlurPopups", "blurPopups",
        "manageBlurPopupsIgnorealpha", "blurPopupsIgnorealpha",
        "manageBlurInputMethods", "blurInputMethods",
        "manageBlurInputMethodsIgnorealpha", "blurInputMethodsIgnorealpha",
        "manageBlurExplicitIgnoreAlpha", "blurExplicitIgnoreAlpha",
        "manageBlurIgnoreAlphaValue", "blurIgnoreAlphaValue",
        "shadowOffset", "shadowColorInactive"
    ]

    // Create a deep copy of the current compositor config
    function createCompositorSnapshot() {
        var snapshot = {};
        for (var i = 0; i < _compositorProps.length; i++) {
            var prop = _compositorProps[i];
            var val = Config.hyprland[prop];
            // Deep copy arrays
            if (Array.isArray(val)) {
                snapshot[prop] = JSON.parse(JSON.stringify(val));
            } else {
                snapshot[prop] = val;
            }
        }
        return snapshot;
    }

    // Restore compositor config from snapshot
    function restoreCompositorSnapshot(snapshot) {
        if (!snapshot) return;
        for (var i = 0; i < _compositorProps.length; i++) {
            var prop = _compositorProps[i];
            if (snapshot[prop] !== undefined) {
                var val = snapshot[prop];
                // Deep copy arrays
                if (Array.isArray(val)) {
                    Config.hyprland[prop] = JSON.parse(JSON.stringify(val));
                } else {
                    Config.hyprland[prop] = val;
                }
            }
        }
    }

    function markCompositorChanged() {
        // Take a snapshot before the first change
        if (!compositorHasChanges) {
            compositorSnapshot = createCompositorSnapshot();
            Config.pauseAutoSave = true;
        }
        compositorHasChanges = true;
    }

    function applyCompositorChanges() {
        if (compositorHasChanges) {
            Config.saveHyprland();
            compositorHasChanges = false;
            compositorSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }

    function discardCompositorChanges() {
        if (compositorHasChanges && compositorSnapshot) {
            restoreCompositorSnapshot(compositorSnapshot);
            compositorHasChanges = false;
            compositorSnapshot = null;
            Config.pauseAutoSave = false;
        }
    }
}
