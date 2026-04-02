pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services

Singleton {
    id: root

    property var iconCache: ({})
    property var runtimeIconCache: ({})
    property var runtimeDesktopEntryCache: ({})
    property var runtimeAssociationCache: ({})
    property var recentLaunches: []
    property var desktopEntryRecords: []
    property var desktopEntryLookup: ({})

    readonly property string bundledFallbackIcon: Qt.resolvedUrl("../../assets/ambxst/app-placeholder.svg")
    readonly property string fallbackIconName: iconExists("application-x-executable") ? "application-x-executable" : bundledFallbackIcon
    readonly property string fallbackIconSource: getIconSource(fallbackIconName)

    function uniqueValues(values) {
        const seen = {};
        const result = [];

        for (let i = 0; i < values.length; i++) {
            const value = values[i];
            if (value === null || value === undefined)
                continue;

            const normalized = String(value).trim();
            if (normalized.length === 0 || seen[normalized])
                continue;

            seen[normalized] = true;
            result.push(normalized);
        }

        return result;
    }

    function getDesktopEntryProp(entry, keys) {
        if (!entry)
            return "";

        for (let i = 0; i < keys.length; i++) {
            const value = entry[keys[i]];
            if (value !== undefined && value !== null && String(value).trim().length > 0)
                return String(value).trim();
        }

        return "";
    }

    function trimWindowTitle(title) {
        const value = String(title || "").trim();
        if (value.length === 0)
            return "";

        const separators = [" - ", " -- ", " | ", " :: ", " — ", " · ", ": "];
        for (let i = 0; i < separators.length; i++) {
            const separator = separators[i];
            const index = value.lastIndexOf(separator);
            if (index > 0)
                return value.slice(index + separator.length).trim();
        }

        return value;
    }

    function canonicalize(str) {
        let value = String(str || "").trim().toLowerCase();
        if (value.length === 0)
            return "";

        value = value.replace(/^.*\//, "");
        value = value.replace(/^flatpak run\s+/i, "");
        value = value.replace(/\.desktop$/i, "");
        value = value.replace(/\.exe$/i, "");
        value = value.replace(/^app-/, "");
        value = value.replace(/[()\[\]{}]/g, " ");
        value = value.replace(/[^a-z0-9]+/g, " ").trim();
        return value.replace(/\s+/g, " ");
    }

    function tokenize(str) {
        const canonical = canonicalize(str);
        if (canonical.length === 0)
            return [];

        return canonical.split(" ").filter(token => token.length > 1);
    }

    function expandCandidateStrings(str) {
        const raw = String(str || "").trim();
        if (raw.length === 0)
            return [];

        const values = [raw];
        const trimmedTitle = trimWindowTitle(raw);
        if (trimmedTitle.length > 0 && trimmedTitle !== raw)
            values.push(trimmedTitle);

        const basename = raw.replace(/^.*\//, "");
        if (basename.length > 0 && basename !== raw)
            values.push(basename);

        const withoutDesktop = basename.replace(/\.desktop$/i, "");
        if (withoutDesktop.length > 0 && withoutDesktop !== basename)
            values.push(withoutDesktop);

        const withoutExe = withoutDesktop.replace(/\.exe$/i, "");
        if (withoutExe.length > 0 && withoutExe !== withoutDesktop)
            values.push(withoutExe);

        const dottedSegments = withoutExe.split(/[.:]/).filter(part => part.length > 0);
        if (dottedSegments.length > 1)
            values.push(dottedSegments[dottedSegments.length - 1]);

        const tokens = tokenize(withoutExe);
        if (tokens.length > 1) {
            values.push(tokens.join(" "));
            values.push(tokens.join("-"));
            values.push(tokens.join("_"));
            values.push(tokens.join(""));
        }

        if (substitutions[raw])
            values.push(substitutions[raw]);
        if (substitutions[withoutExe])
            values.push(substitutions[withoutExe]);

        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replaced = raw.replace(substitution.regex, substitution.replace);
            if (replaced !== raw)
                values.push(replaced);
        }

        return uniqueValues(values);
    }

    function buildCandidateBundle(values) {
        const raw = uniqueValues(values);
        const expanded = [];
        for (let i = 0; i < raw.length; i++) {
            const variants = expandCandidateStrings(raw[i]);
            for (let j = 0; j < variants.length; j++)
                expanded.push(variants[j]);
        }

        const uniqueExpanded = uniqueValues(expanded);
        const canonicals = [];
        for (let i = 0; i < uniqueExpanded.length; i++) {
            const canonical = canonicalize(uniqueExpanded[i]);
            if (canonical.length > 0)
                canonicals.push(canonical);
        }

        const uniqueCanonicals = uniqueValues(canonicals);
        const tokens = [];
        for (let i = 0; i < uniqueCanonicals.length; i++) {
            const candidateTokens = tokenize(uniqueCanonicals[i]);
            for (let j = 0; j < candidateTokens.length; j++)
                tokens.push(candidateTokens[j]);
        }

        return {
            raw: raw,
            expanded: uniqueExpanded,
            canonicals: uniqueCanonicals,
            tokens: uniqueValues(tokens)
        };
    }

    function getEntryExecCandidates(app) {
        const values = [];
        const command = app?.command || [];

        if (command.length > 0) {
            values.push(command[0]);
            values.push(command.join(" "));
            values.push(String(command[0]).replace(/^.*\//, ""));
        }

        if (app?.execString)
            values.push(app.execString);

        return values;
    }

    function buildEntryRecord(app) {
        const startupWmClass = getDesktopEntryProp(app, ["startupWmClass", "startupWMClass", "StartupWMClass", "wmClass"]);
        const candidates = [];

        candidates.push(app?.id || "");
        candidates.push(app?.name || "");
        candidates.push(app?.genericName || "");
        candidates.push(app?.icon || "");
        candidates.push(startupWmClass);

        const keywords = app?.keywords || [];
        for (let i = 0; i < keywords.length; i++)
            candidates.push(keywords[i]);

        const execCandidates = getEntryExecCandidates(app);
        for (let i = 0; i < execCandidates.length; i++)
            candidates.push(execCandidates[i]);

        const bundle = buildCandidateBundle(candidates);
        return {
            app: app,
            startupWmClass: startupWmClass,
            candidates: bundle.expanded,
            canonicalCandidates: bundle.canonicals,
            tokens: bundle.tokens
        };
    }

    function getCachedIcon(str) {
        if (!str)
            return fallbackIconName;
        if (iconCache[str])
            return iconCache[str];

        const result = guessIcon(str);
        iconCache[str] = result;
        return result;
    }

    function iconExists(iconName) {
        if (!iconName)
            return false;

        const iconString = String(iconName);
        if (iconString.startsWith("file:"))
            return true;
        if (iconString.startsWith("/"))
            return Quickshell.iconPath(iconString, true).length > 0;

        return Quickshell.iconPath(iconString, true).length > 0 && !iconString.includes("image-missing");
    }

    function validateIcon(iconName) {
        if (!iconName || iconName.length === 0)
            return fallbackIconName;

        if (iconName.startsWith("file:"))
            return iconName;

        if (iconName.startsWith("/")) {
            const resolvedPath = Quickshell.iconPath(iconName, true);
            if (resolvedPath.length === 0)
                return fallbackIconName;
            return iconName;
        }

        if (iconExists(iconName))
            return iconName;

        return fallbackIconName;
    }

    function getIconSource(iconName) {
        const validated = validateIcon(iconName);
        if (validated.startsWith("/") || validated.startsWith("file:"))
            return validated;
        return Quickshell.iconPath(validated, bundledFallbackIcon);
    }

    function rememberRuntimeAssociation(candidateBundle, entry) {
        if (!entry)
            return;

        const nextCache = Object.assign({}, runtimeAssociationCache);
        for (let i = 0; i < candidateBundle.canonicals.length; i++) {
            const key = candidateBundle.canonicals[i];
            if (key.length > 0)
                nextCache[key] = entry;
        }
        runtimeAssociationCache = nextCache;
    }

    function getRecentLaunchMatch(candidateBundle) {
        if (!recentLaunches || recentLaunches.length === 0)
            return null;

        const now = Date.now();
        let bestEntry = null;
        let bestScore = 0;

        for (let i = 0; i < recentLaunches.length; i++) {
            const launch = recentLaunches[i];
            if (!launch?.entry || now - launch.timestamp > 30000)
                continue;

            let score = 0;
            for (let j = 0; j < launch.canonicalCandidates.length; j++) {
                if (candidateBundle.canonicals.includes(launch.canonicalCandidates[j]))
                    score += 20;
            }

            for (let j = 0; j < launch.tokens.length; j++) {
                if (candidateBundle.tokens.includes(launch.tokens[j]))
                    score += 8;
            }

            for (let j = 0; j < candidateBundle.canonicals.length; j++) {
                const candidate = candidateBundle.canonicals[j];
                for (let k = 0; k < launch.canonicalCandidates.length; k++) {
                    const launchCandidate = launch.canonicalCandidates[k];
                    if (candidate.length === 0 || launchCandidate.length === 0)
                        continue;
                    if (candidate.includes(launchCandidate) || launchCandidate.includes(candidate))
                        score += 3;
                }
            }

            if (score > bestScore) {
                bestScore = score;
                bestEntry = launch.entry;
            }
        }

        return bestScore >= 12 ? bestEntry : null;
    }

    function findDesktopEntryByCandidates(candidateValues) {
        const candidateBundle = buildCandidateBundle(candidateValues);

        for (let i = 0; i < candidateBundle.canonicals.length; i++) {
            const exactMatch = desktopEntryLookup[candidateBundle.canonicals[i]];
            if (exactMatch)
                return exactMatch;
        }

        for (let i = 0; i < candidateBundle.expanded.length; i++) {
            const heuristic = DesktopEntries.heuristicLookup(candidateBundle.expanded[i]);
            if (heuristic)
                return heuristic;
        }

        for (let i = 0; i < candidateBundle.canonicals.length; i++) {
            const associated = runtimeAssociationCache[candidateBundle.canonicals[i]];
            if (associated)
                return associated;
        }

        let bestRecord = null;
        let bestScore = 0;

        for (let i = 0; i < desktopEntryRecords.length; i++) {
            const record = desktopEntryRecords[i];
            let score = 0;

            for (let j = 0; j < record.canonicalCandidates.length; j++) {
                const entryCandidate = record.canonicalCandidates[j];
                if (candidateBundle.canonicals.includes(entryCandidate))
                    score += 25;
            }

            for (let j = 0; j < record.tokens.length; j++) {
                if (candidateBundle.tokens.includes(record.tokens[j]))
                    score += 5;
            }

            for (let j = 0; j < candidateBundle.canonicals.length; j++) {
                const candidate = candidateBundle.canonicals[j];
                if (candidate.length === 0)
                    continue;

                for (let k = 0; k < record.canonicalCandidates.length; k++) {
                    const entryCandidate = record.canonicalCandidates[k];
                    if (entryCandidate.length === 0)
                        continue;
                    if (candidate === entryCandidate)
                        score += 25;
                    else if (candidate.startsWith(entryCandidate) || entryCandidate.startsWith(candidate))
                        score += 10;
                    else if (candidate.includes(entryCandidate) || entryCandidate.includes(candidate))
                        score += 4;
                }
            }

            if (score > bestScore) {
                bestScore = score;
                bestRecord = record;
            }
        }

        if (bestRecord && bestScore >= 12)
            return bestRecord.app;

        return getRecentLaunchMatch(candidateBundle);
    }

    function resolveRuntimeDesktopEntry(info) {
        if (info?.desktopEntry)
            return info.desktopEntry;

        const candidateValues = [
            info?.desktopEntryId || "",
            info?.appId || "",
            info?.wmClass || "",
            info?.initialClass || "",
            info?.title || ""
        ];
        const cacheKey = buildCandidateBundle(candidateValues).canonicals.join("|");

        if (cacheKey.length > 0 && runtimeDesktopEntryCache[cacheKey])
            return runtimeDesktopEntryCache[cacheKey];

        const entry = findDesktopEntryByCandidates(candidateValues);
        if (cacheKey.length > 0 && entry)
            runtimeDesktopEntryCache[cacheKey] = entry;

        return entry;
    }

    function resolveRuntimeIcon(info) {
        const entry = resolveRuntimeDesktopEntry(info);
        const candidateValues = [
            info?.desktopEntryId || "",
            info?.appId || "",
            info?.wmClass || "",
            info?.initialClass || "",
            info?.title || "",
            entry?.icon || ""
        ];
        const candidateBundle = buildCandidateBundle(candidateValues);

        if (entry) {
            rememberRuntimeAssociation(candidateBundle, entry);
            const entryIcon = validateIcon(entry.icon || "");
            if (entryIcon !== fallbackIconName || !!entry.icon)
                return entryIcon;
        }

        for (let i = 0; i < candidateBundle.expanded.length; i++) {
            const guessed = validateIcon(guessIcon(candidateBundle.expanded[i]));
            if (guessed !== fallbackIconName)
                return guessed;
        }

        const recentEntry = getRecentLaunchMatch(candidateBundle);
        if (recentEntry)
            return validateIcon(recentEntry.icon || "");

        return fallbackIconName;
    }

    function getResolvedIconSource(info) {
        const cacheKey = JSON.stringify({
            appId: info?.appId || "",
            wmClass: info?.wmClass || "",
            initialClass: info?.initialClass || "",
            title: info?.title || "",
            desktopEntryId: info?.desktopEntryId || "",
            desktopIcon: info?.desktopEntry?.icon || ""
        });

        if (runtimeIconCache[cacheKey])
            return runtimeIconCache[cacheKey];

        const source = getIconSource(resolveRuntimeIcon(info));
        runtimeIconCache[cacheKey] = source;
        return source;
    }

    function getIconFromDesktopEntry(value) {
        if (!value || value.length === 0)
            return null;

        const entry = findDesktopEntryByCandidates([value]);
        return entry?.icon || null;
    }

    function guessIcon(str) {
        if (!str || str.length === 0)
            return fallbackIconName;

        const desktopIcon = getIconFromDesktopEntry(str);
        if (desktopIcon)
            return desktopIcon;

        if (substitutions[str])
            return substitutions[str];

        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replacedName = str.replace(substitution.regex, substitution.replace);
            if (replacedName !== str)
                return replacedName;
        }

        if (iconExists(str))
            return str;

        const extensionGuess = str.split(".").pop().toLowerCase();
        if (iconExists(extensionGuess))
            return extensionGuess;

        const dashedGuess = str.toLowerCase().replace(/\s+/g, "-");
        if (iconExists(dashedGuess))
            return dashedGuess;

        return fallbackIconName;
    }

    property var substitutions: ({
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "footclient": "foot",
        "zen": "zen-browser",
        "battle.net": "lutris_battlenet",
        "battle net": "lutris_battlenet",
        "battle.net.exe": "lutris_battlenet",
        "battlenet": "lutris_battlenet",
        "unity": "unityhub",
        "unity hub": "unityhub",
        "unityhub": "unityhub"
    })
    property list<var> regexSubstitutions: [
        {
            "regex": /^steam_app_(\d+)$/,
            "replace": "steam_icon_$1"
        },
        {
            "regex": /Minecraft.*/,
            "replace": "minecraft"
        },
        {
            "regex": /.*polkit.*/,
            "replace": "system-lock-screen"
        },
        {
            "regex": /gcr.prompter/,
            "replace": "system-lock-screen"
        }
    ]

    readonly property list<DesktopEntry> list: Array.from(DesktopEntries.applications.values)
        .sort((a, b) => a.name.localeCompare(b.name))

    property var searchIndex: []
    property var allAppsCache: null

    function buildIndex() {
        const newIndex = [];
        const entryRecords = [];
        const entryLookup = {};

        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            const record = buildEntryRecord(app);
            entryRecords.push(record);

            for (let j = 0; j < record.canonicalCandidates.length; j++) {
                const key = record.canonicalCandidates[j];
                if (key.length > 0 && !entryLookup[key])
                    entryLookup[key] = app;
            }

            newIndex.push({
                name: app.name.toLowerCase(),
                command: (app.command && app.command.length > 0) ? app.command.join(" ").toLowerCase() : "",
                executable: (app.command && app.command.length > 0) ? String(app.command[0]).toLowerCase() : "",
                comment: (app.comment || "").toLowerCase(),
                genericName: (app.genericName || "").toLowerCase(),
                keywords: (app.keywords || []).map(k => String(k).toLowerCase()),
                original: app
            });
        }

        searchIndex = newIndex;
        desktopEntryRecords = entryRecords;
        desktopEntryLookup = entryLookup;
    }

    function invalidateCache() {
        allAppsCache = null;
        iconCache = ({});
        runtimeIconCache = ({});
        runtimeDesktopEntryCache = ({});
        runtimeAssociationCache = ({});
    }

    onListChanged: {
        invalidateCache();
        buildIndex();
    }

    Component.onCompleted: {
        buildIndex();
    }

    function registerLaunch(app) {
        const record = buildEntryRecord(app);
        const filtered = recentLaunches.filter(item => (Date.now() - item.timestamp) < 30000);
        recentLaunches = [{
            timestamp: Date.now(),
            entry: app,
            canonicalCandidates: record.canonicalCandidates,
            tokens: record.tokens
        }].concat(filtered).slice(0, 12);
    }

    function launchApp(app) {
        registerLaunch(app);

        const path = app.fileName || app.path || app.filePath;

        if (path && path.toString().endsWith(".desktop")) {
            const escapedPath = path.toString().replace(/'/g, "'\\''");
            const p = Qt.createQmlObject("import Quickshell.Io; Process { }", root);
            p.command = ["bash", "-c", "cd ~ && setsid gio launch '" + escapedPath + "' > /dev/null 2>&1 &"];
            p.running = true;
            return;
        }

        if (app.command && app.command.length > 0) {
            const safeArgs = [];
            for (let i = 0; i < app.command.length; i++) {
                const arg = app.command[i];
                if (/^%[fFuUijkc]$/.test(arg))
                    continue;
                safeArgs.push("'" + String(arg).replace(/'/g, "'\\''") + "'");
            }

            if (safeArgs.length > 0) {
                const cmdString = safeArgs.join(" ");
                const p = Qt.createQmlObject("import Quickshell.Io; Process { }", root);
                p.command = ["bash", "-c", "cd ~ && setsid " + cmdString + " > /dev/null 2>&1 &"];
                p.running = true;
                return;
            }
        }

        app.execute();
    }

    function getAllApps() {
        if (allAppsCache)
            return allAppsCache;

        const results = [];

        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            const usageScore = UsageTracker.getUsageScore(app.id);

            let iconToUse = app.icon || fallbackIconName;
            if (iconCache[iconToUse]) {
                iconToUse = iconCache[iconToUse];
            } else {
                const validated = validateIcon(iconToUse);
                iconCache[iconToUse] = validated;
                iconToUse = validated;
            }

            results.push({
                name: app.name,
                icon: iconToUse,
                id: app.id,
                execString: app.execString,
                comment: app.comment || "",
                categories: app.categories || [],
                runInTerminal: app.runInTerminal || false,
                usageScore: usageScore,
                execute: () => {
                    launchApp(app);
                }
            });
        }

        results.sort((a, b) => {
            if (a.usageScore !== b.usageScore)
                return b.usageScore - a.usageScore;
            return a.name.localeCompare(b.name);
        });

        allAppsCache = results;
        return results;
    }

    function fuzzyQuery(search) {
        if (!search || search.length === 0)
            return [];

        const searchLower = search.toLowerCase();
        const results = [];

        if (searchIndex.length === 0 && list.length > 0)
            buildIndex();

        for (let i = 0; i < searchIndex.length; i++) {
            const entry = searchIndex[i];
            let score = 0;
            let matchFound = false;

            if (entry.name === searchLower) {
                score += 100;
                matchFound = true;
            } else if (entry.name.startsWith(searchLower)) {
                score += 80;
                matchFound = true;
            } else if (entry.name.includes(searchLower)) {
                score += 60;
                matchFound = true;
            }

            if (entry.command) {
                if (entry.command.includes(searchLower)) {
                    score += 40;
                    matchFound = true;
                }
                if (entry.executable.includes(searchLower)) {
                    score += 50;
                    matchFound = true;
                }
            }

            if (entry.comment && entry.comment.includes(searchLower)) {
                score += 30;
                matchFound = true;
            }

            if (entry.genericName && entry.genericName.includes(searchLower)) {
                score += 25;
                matchFound = true;
            }

            if (entry.keywords.length > 0) {
                for (let j = 0; j < entry.keywords.length; j++) {
                    if (entry.keywords[j].includes(searchLower)) {
                        score += 20;
                        matchFound = true;
                        break;
                    }
                }
            }

            if (matchFound) {
                const app = entry.original;
                const usageScore = UsageTracker.getUsageScore(app.id);
                let iconToUse = app.icon || fallbackIconName;

                if (iconCache[iconToUse]) {
                    iconToUse = iconCache[iconToUse];
                } else {
                    const validated = validateIcon(iconToUse);
                    iconCache[iconToUse] = validated;
                    iconToUse = validated;
                }

                results.push({
                    name: app.name,
                    icon: iconToUse,
                    score: score,
                    id: app.id,
                    execString: app.execString,
                    comment: app.comment || "",
                    categories: app.categories || [],
                    runInTerminal: app.runInTerminal || false,
                    usageScore: usageScore,
                    execute: () => {
                        launchApp(app);
                    }
                });
            }
        }

        results.sort((a, b) => {
            const totalScoreA = a.score + a.usageScore;
            const totalScoreB = b.score + b.usageScore;

            if (totalScoreA !== totalScoreB)
                return totalScoreB - totalScoreA;
            return (a.name || "").localeCompare(b.name || "");
        });

        return results.slice(0, 10);
    }
}
