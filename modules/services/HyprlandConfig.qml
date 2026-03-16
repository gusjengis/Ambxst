import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import qs.modules.theme
import qs.modules.bar
import qs.modules.globals

QtObject {
    id: root

    property Process hyprctlProcess: Process {}
    property Process hyprctlReloadProcess: Process {
        command: ["hyprctl", "reload"]
    }

    property var currentAnimationConfig: null
    property Process readAnimationsProcess: Process {
        command: ["hyprctl", "-j", "animations"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        // hyprctl -j animations returns [animations, beziers]
                        currentAnimationConfig = parsed;
                    }
                } catch (e) {
                    console.error("HyprlandConfig: Error parsing animations:", e);
                }
            }
        }
    }

    property var barInstances: []

    function registerBar(barInstance) {
        barInstances.push(barInstance);
    }

    function getBarOrientation() {
        if (barInstances.length > 0) {
            return barInstances[0].orientation || "horizontal";
        }
        const position = Config.bar.position || "top";
        return (position === "left" || position === "right") ? "vertical" : "horizontal";
    }

    property Timer applyTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: applyHyprlandConfigInternal()
    }

    function getColorValue(colorName) {
        const resolved = Config.resolveColor(colorName);
        // Convert HEX string to color, or return if already a color.
        return (typeof resolved === 'string') ? Qt.color(resolved) : resolved;
    }

    function formatColorForHyprland(color) {
        // Hyprland expects colors in format: rgb(rrggbb) or rgba(rrggbbaa)
        const r = Math.round(color.r * 255).toString(16).padStart(2, '0');
        const g = Math.round(color.g * 255).toString(16).padStart(2, '0');
        const b = Math.round(color.b * 255).toString(16).padStart(2, '0');
        const a = Math.round(color.a * 255).toString(16).padStart(2, '0');

        if (color.a === 1.0) {
            return `rgb(${r}${g}${b})`;
        } else {
            return `rgba(${r}${g}${b}${a})`;
        }
    }

    function applyHyprlandConfig() {
        readAnimationsProcess.running = true;
        applyTimer.restart();
    }

    function getManagedSettingDescriptors(activeColorFormatted, inactiveColorFormatted, shadowColorFormatted, shadowColorInactiveFormatted, workspaceCommand) {
        return [
            { key: "general:border_size", value: Config.hyprland.borderSize, managed: Config.hyprland.manageBorderSize ?? true },
            { key: "general:gaps_in", value: Config.hyprland.gapsIn, managed: Config.hyprland.manageGapsIn ?? true },
            { key: "general:gaps_out", value: Config.hyprland.gapsOut, managed: Config.hyprland.manageGapsOut ?? true },
            { key: "general:col.active_border", value: activeColorFormatted, managed: true },
            { key: "general:col.inactive_border", value: inactiveColorFormatted, managed: true },
            { key: "general:layout", value: GlobalStates.hyprlandLayout, managed: Config.hyprland.manageLayout ?? true },
            { key: "decoration:rounding", value: Config.hyprland.rounding, managed: Config.hyprland.manageRounding ?? true },
            { key: "decoration:shadow:enabled", value: Config.hyprland.shadowEnabled, managed: true },
            { key: "decoration:shadow:range", value: Config.hyprland.shadowRange, managed: true },
            { key: "decoration:shadow:render_power", value: Config.hyprland.shadowRenderPower, managed: true },
            { key: "decoration:shadow:sharp", value: Config.hyprland.shadowSharp, managed: true },
            { key: "decoration:shadow:ignore_window", value: Config.hyprland.shadowIgnoreWindow, managed: true },
            { key: "decoration:shadow:color", value: shadowColorFormatted, managed: true },
            { key: "decoration:shadow:color_inactive", value: shadowColorInactiveFormatted, managed: true },
            { key: "decoration:shadow:offset", value: Config.hyprland.shadowOffset, managed: true },
            { key: "decoration:shadow:scale", value: Config.hyprland.shadowScale, managed: true },
            { key: "decoration:blur:enabled", value: Config.hyprland.blurEnabled, managed: Config.hyprland.manageBlurEnabled ?? true },
            { key: "decoration:blur:size", value: Config.hyprland.blurSize, managed: Config.hyprland.manageBlurSize ?? true },
            { key: "decoration:blur:passes", value: Config.hyprland.blurPasses, managed: Config.hyprland.manageBlurPasses ?? true },
            { key: "decoration:blur:ignore_opacity", value: Config.hyprland.blurIgnoreOpacity, managed: Config.hyprland.manageBlurIgnoreOpacity ?? true },
            { key: "decoration:blur:new_optimizations", value: Config.hyprland.blurNewOptimizations, managed: Config.hyprland.manageBlurNewOptimizations ?? true },
            { key: "decoration:blur:xray", value: Config.hyprland.blurXray, managed: Config.hyprland.manageBlurXray ?? true },
            { key: "decoration:blur:noise", value: Config.hyprland.blurNoise, managed: Config.hyprland.manageBlurNoise ?? true },
            { key: "decoration:blur:contrast", value: Config.hyprland.blurContrast, managed: Config.hyprland.manageBlurContrast ?? true },
            { key: "decoration:blur:brightness", value: Config.hyprland.blurBrightness, managed: Config.hyprland.manageBlurBrightness ?? true },
            { key: "decoration:blur:vibrancy", value: Config.hyprland.blurVibrancy, managed: Config.hyprland.manageBlurVibrancy ?? true },
            { key: "decoration:blur:vibrancy_darkness", value: Config.hyprland.blurVibrancyDarkness, managed: Config.hyprland.manageBlurVibrancyDarkness ?? true },
            { key: "decoration:blur:special", value: Config.hyprland.blurSpecial, managed: Config.hyprland.manageBlurSpecial ?? true },
            { key: "decoration:blur:popups", value: Config.hyprland.blurPopups, managed: Config.hyprland.manageBlurPopups ?? true },
            { key: "decoration:blur:popups_ignorealpha", value: Config.hyprland.blurPopupsIgnorealpha, managed: Config.hyprland.manageBlurPopupsIgnorealpha ?? true },
            { key: "decoration:blur:input_methods", value: Config.hyprland.blurInputMethods, managed: Config.hyprland.manageBlurInputMethods ?? true },
            { key: "decoration:blur:input_methods_ignorealpha", value: Config.hyprland.blurInputMethodsIgnorealpha, managed: Config.hyprland.manageBlurInputMethodsIgnorealpha ?? true },
            { raw: "keyword bezier myBezier,0.4,0.0,0.2,1.0", managed: true },
            { raw: "keyword animation windows,1,2.5,myBezier,popin 80%", managed: true },
            { raw: "keyword animation border,1,2.5,myBezier", managed: true },
            { raw: "keyword animation fade,1,2.5,myBezier", managed: true },
            { raw: workspaceCommand, managed: true }
        ];
    }

    function applyHyprlandConfigInternal() {
        // Ensure adapters are loaded before applying config.
        if (!Config.loader.loaded) {
            console.log("HyprlandConfig: Esperando que se cargue Config...");
            return;
        }

        // Wait for layout to be ready.
        if (!GlobalStates.hyprlandLayoutReady) {
            console.log("HyprlandConfig: Esperando que se detecte el layout de Hyprland...");
            return;
        }

        // Determine active colors.
        let activeColorFormatted = "";
        // Force hyprlandBorderColor if syncBorderColor is enabled, otherwise use configured list (supports gradients).
        const borderColors = Config.hyprland.syncBorderColor ? null : Config.hyprland.activeBorderColor;

        if (borderColors && borderColors.length > 1) {
            // Multi-color gradient.
            const formattedColors = borderColors.map(colorName => {
                const color = getColorValue(colorName);
                return formatColorForHyprland(color);
            }).join(" ");
            activeColorFormatted = `${formattedColors} ${Config.hyprland.borderAngle}deg`;
        } else {
            // Single color: if sync enabled or empty, use hyprlandBorderColor; otherwise use first element.
            const singleColorName = (borderColors && borderColors.length === 1) ? borderColors[0] : Config.hyprlandBorderColor;
            const activeColor = getColorValue(singleColorName);
            activeColorFormatted = formatColorForHyprland(activeColor);
        }

        // Determine inactive colors.
        let inactiveColorFormatted = "";
        const inactiveBorderColors = Config.hyprland.inactiveBorderColor;

        if (inactiveBorderColors && inactiveBorderColors.length > 1) {
            // Multi-color gradient.
            const formattedColors = inactiveBorderColors.map(colorName => {
                const color = getColorValue(colorName);
                const colorWithFullOpacity = Qt.rgba(color.r, color.g, color.b, 1.0);
                return formatColorForHyprland(colorWithFullOpacity);
            }).join(" ");
            inactiveColorFormatted = `${formattedColors} ${Config.hyprland.inactiveBorderAngle}deg`;
        } else {
            // Single color.
            const singleColorName = (inactiveBorderColors && inactiveBorderColors.length === 1) ? inactiveBorderColors[0] : "surface";
            const inactiveColor = getColorValue(singleColorName);
            const inactiveColorWithFullOpacity = Qt.rgba(inactiveColor.r, inactiveColor.g, inactiveColor.b, 1.0);
            inactiveColorFormatted = formatColorForHyprland(inactiveColorWithFullOpacity);
        }

        // Shadow colors.
        const shadowColor = getColorValue(Config.hyprlandShadowColor);
        const shadowColorInactive = getColorValue(Config.hyprland.shadowColorInactive);
        const shadowColorWithOpacity = Qt.rgba(shadowColor.r, shadowColor.g, shadowColor.b, shadowColor.a * Config.hyprlandShadowOpacity);
        const shadowColorInactiveWithOpacity = Qt.rgba(shadowColorInactive.r, shadowColorInactive.g, shadowColorInactive.b, shadowColorInactive.a * Config.hyprlandShadowOpacity);
        const shadowColorFormatted = formatColorForHyprland(shadowColorWithOpacity);
        const shadowColorInactiveFormatted = formatColorForHyprland(shadowColorInactiveWithOpacity);

        const barOrientation = getBarOrientation();
        let speed = 2.5;
        let bezier = "default";
        
        if (currentAnimationConfig && currentAnimationConfig[0]) {
            const workspaceAnim = currentAnimationConfig[0].find(anim => anim.name === "workspaces");
            if (workspaceAnim) {
                speed = workspaceAnim.speed || speed;
                bezier = workspaceAnim.bezier || bezier;
            }
        }

        const workspacesAnimation = barOrientation === "vertical" ? `slidefadevert 20%` : `slidefade 20%`;
        const workspaceCommand = `keyword animation workspaces,1,${speed},${bezier},${workspacesAnimation}`;

        // Calculate ignorealpha.
        let ignoreAlphaValue = 0.0;

        if (Config.hyprland.blurExplicitIgnoreAlpha) {
            ignoreAlphaValue = Config.hyprland.blurIgnoreAlphaValue.toFixed(2);
        } else {
            // Dynamic ignorealpha based on StyledRect opacity.
            // Use min(barbg, bg) opacity if barbg > 0, else use bg.
            const barBgOpacity = (Config.theme.srBarBg && Config.theme.srBarBg.opacity !== undefined) ? Config.theme.srBarBg.opacity : 0;
            const bgOpacity = (Config.theme.srBg && Config.theme.srBg.opacity !== undefined) ? Config.theme.srBg.opacity : 1.0;
            ignoreAlphaValue = (barBgOpacity > 0 ? Math.min(barBgOpacity, bgOpacity) : bgOpacity).toFixed(2);
            console.log(`HyprlandConfig: Auto ignorealpha calculated: ${ignoreAlphaValue} (bg: ${bgOpacity}, bar: ${barBgOpacity})`);
        }

        const batchParts = getManagedSettingDescriptors(activeColorFormatted, inactiveColorFormatted, shadowColorFormatted, shadowColorInactiveFormatted, workspaceCommand)
            .filter(setting => setting.managed)
            .map(setting => setting.raw ?? `keyword ${setting.key} ${setting.value}`);
        // Note: workspaceCommand is dynamically calculated based on current animations and orientation.

        console.log(`HyprlandConfig: Applying ignorealpha: ${ignoreAlphaValue}, explicit: ${Config.hyprland.blurExplicitIgnoreAlpha}`);
        batchParts.push(`keyword layerrule noanim,quickshell`);
        batchParts.push(`keyword layerrule blur,quickshell`);
        batchParts.push(`keyword layerrule blurpopups,quickshell`);
        batchParts.push(`keyword layerrule ignorealpha ${ignoreAlphaValue},quickshell`);
        const batchCommand = batchParts.join(" ; ");
        console.log("HyprlandConfig: Applying hyprctl batch command:", batchCommand);
        hyprctlProcess.command = ["hyprctl", "--batch", batchCommand];
        hyprctlProcess.running = true;
    }

    property Connections configConnections: Connections {
        target: Config.loader
        function onFileChanged() {
            applyHyprlandConfig();
        }
        function onLoaded() {
            applyHyprlandConfig();
        }
    }

    property Connections hyprlandConfigConnections: Connections {
        target: Config.hyprland
        function onLayoutChanged() {
            if (Config.hyprland.manageLayout ?? true) {
                GlobalStates.setHyprlandLayout(Config.hyprland.layout);
                applyHyprlandConfig();
            }
        }
        function onBorderSizeChanged() {
            applyHyprlandConfig();
        }
        function onManageBorderSizeChanged() {
            if (!(Config.hyprland.manageBorderSize ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onRoundingChanged() {
            applyHyprlandConfig();
        }
        function onManageRoundingChanged() {
            if (!(Config.hyprland.manageRounding ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onGapsInChanged() {
            applyHyprlandConfig();
        }
        function onManageGapsInChanged() {
            if (!(Config.hyprland.manageGapsIn ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onGapsOutChanged() {
            applyHyprlandConfig();
        }
        function onManageGapsOutChanged() {
            if (!(Config.hyprland.manageGapsOut ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onManageLayoutChanged() {
            if (!(Config.hyprland.manageLayout ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            GlobalStates.setHyprlandLayout(Config.hyprland.layout);
            applyHyprlandConfig();
        }
        function onActiveBorderColorChanged() {
            applyHyprlandConfig();
        }
        function onInactiveBorderColorChanged() {
            applyHyprlandConfig();
        }
        function onBorderAngleChanged() {
            applyHyprlandConfig();
        }
        function onInactiveBorderAngleChanged() {
            applyHyprlandConfig();
        }
        function onSyncRoundnessChanged() {
            applyHyprlandConfig();
        }
        function onSyncBorderWidthChanged() {
            applyHyprlandConfig();
        }
        function onSyncBorderColorChanged() {
            applyHyprlandConfig();
        }
        function onSyncShadowOpacityChanged() {
            applyHyprlandConfig();
        }
        function onSyncShadowColorChanged() {
            applyHyprlandConfig();
        }
        function onShadowEnabledChanged() {
            applyHyprlandConfig();
        }
        function onShadowRangeChanged() {
            applyHyprlandConfig();
        }
        function onShadowRenderPowerChanged() {
            applyHyprlandConfig();
        }
        function onShadowSharpChanged() {
            applyHyprlandConfig();
        }
        function onShadowIgnoreWindowChanged() {
            applyHyprlandConfig();
        }
        function onShadowColorChanged() {
            applyHyprlandConfig();
        }
        function onShadowColorInactiveChanged() {
            applyHyprlandConfig();
        }
        function onShadowOpacityChanged() {
            applyHyprlandConfig();
        }
        function onShadowOffsetChanged() {
            applyHyprlandConfig();
        }
        function onShadowScaleChanged() {
            applyHyprlandConfig();
        }
        function onBlurEnabledChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurEnabledChanged() {
            if (!(Config.hyprland.manageBlurEnabled ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurSizeChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurSizeChanged() {
            if (!(Config.hyprland.manageBlurSize ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurPassesChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurPassesChanged() {
            if (!(Config.hyprland.manageBlurPasses ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurIgnoreOpacityChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurIgnoreOpacityChanged() {
            if (!(Config.hyprland.manageBlurIgnoreOpacity ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurExplicitIgnoreAlphaChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurExplicitIgnoreAlphaChanged() {
            if (!(Config.hyprland.manageBlurExplicitIgnoreAlpha ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurIgnoreAlphaValueChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurIgnoreAlphaValueChanged() {
            if (!(Config.hyprland.manageBlurIgnoreAlphaValue ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurNewOptimizationsChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurNewOptimizationsChanged() {
            if (!(Config.hyprland.manageBlurNewOptimizations ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurXrayChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurXrayChanged() {
            if (!(Config.hyprland.manageBlurXray ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurNoiseChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurNoiseChanged() {
            if (!(Config.hyprland.manageBlurNoise ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurContrastChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurContrastChanged() {
            if (!(Config.hyprland.manageBlurContrast ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurBrightnessChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurBrightnessChanged() {
            if (!(Config.hyprland.manageBlurBrightness ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurVibrancyChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurVibrancyChanged() {
            if (!(Config.hyprland.manageBlurVibrancy ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurVibrancyDarknessChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurVibrancyDarknessChanged() {
            if (!(Config.hyprland.manageBlurVibrancyDarkness ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurSpecialChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurSpecialChanged() {
            if (!(Config.hyprland.manageBlurSpecial ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurPopupsChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurPopupsChanged() {
            if (!(Config.hyprland.manageBlurPopups ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurPopupsIgnorealphaChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurPopupsIgnorealphaChanged() {
            if (!(Config.hyprland.manageBlurPopupsIgnorealpha ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurInputMethodsChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurInputMethodsChanged() {
            if (!(Config.hyprland.manageBlurInputMethods ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
        function onBlurInputMethodsIgnorealphaChanged() {
            applyHyprlandConfig();
        }
        function onManageBlurInputMethodsIgnorealphaChanged() {
            if (!(Config.hyprland.manageBlurInputMethodsIgnorealpha ?? true)) {
                hyprctlReloadProcess.running = true;
                return;
            }

            applyHyprlandConfig();
        }
    }

    property Connections colorsConnections: Connections {
        target: Colors
        function onFileChanged() {
            applyHyprlandConfig();
        }
        function onLoaded() {
            applyHyprlandConfig();
        }
    }

    property Connections barConnections: Connections {
        target: Config.bar
        function onPositionChanged() {
            applyHyprlandConfig();
        }
    }

    property Connections srBgConnections: Connections {
        target: Config.theme.srBg
        function onOpacityChanged() {
            applyHyprlandConfig();
        }
    }

    property Connections srBarBgConnections: Connections {
        target: Config.theme.srBarBg
        function onOpacityChanged() {
            applyHyprlandConfig();
        }
    }

    property Connections globalStatesConnections: Connections {
        target: GlobalStates
        function onHyprlandLayoutChanged() {
            applyHyprlandConfig();
        }
        function onHyprlandLayoutReadyChanged() {
            if (GlobalStates.hyprlandLayoutReady) {
                applyHyprlandConfig();
            }
        }
    }

    property Connections hyprlandConnections: Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                console.log("HyprlandConfig: Detectado configreloaded, reaplicando configuración...");
                GlobalStates.refreshManagedHyprlandValues();
                applyHyprlandConfig();
            }
        }
    }

    Component.onCompleted: {
        GlobalStates.refreshManagedHyprlandValues();
        // Apply immediately if Config is already loaded.
        if (Config.loader.loaded) {
            applyHyprlandConfig();
        }
        // Otherwise, handled by onLoaded.
    }
}
