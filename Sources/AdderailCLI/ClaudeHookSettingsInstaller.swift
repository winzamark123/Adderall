import Foundation

struct ClaudeHookSettingsInstaller {
    let settingsURL: URL
    let adderailURL: URL

    static func defaultSettingsURL() -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let settingsPath = environment["ADDERAIL_CLAUDE_SETTINGS_PATH"], settingsPath.isEmpty == false {
            return URL(fileURLWithPath: NSString(string: settingsPath).expandingTildeInPath)
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    func prepareInstall() throws -> ClaudeHookSettingsPlan {
        let settingsExisted = FileManager.default.fileExists(atPath: settingsURL.path)
        var settings = try readSettings()
        var hooks = try hooksObject(in: settings)

        _ = removeAdderailHandlers(from: &hooks)

        for group in Self.hookGroups {
            var groups = try eventGroups(for: group.eventName, in: hooks)
            groups.append(group.dictionary(adderailURL: adderailURL))
            hooks[group.eventName] = groups
        }

        settings["hooks"] = hooks

        return ClaudeHookSettingsPlan(
            settings: settings,
            settingsExisted: settingsExisted,
            changedEvents: Self.hookGroups.map(\.eventName)
        )
    }

    func install() throws -> ClaudeHookSettingsChange {
        try install(preparedPlan: prepareInstall())
    }

    func install(preparedPlan: ClaudeHookSettingsPlan) throws -> ClaudeHookSettingsChange {
        try apply(plan: preparedPlan)
    }

    func uninstall() throws -> ClaudeHookSettingsChange {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return ClaudeHookSettingsChange(
                settingsURL: settingsURL,
                backupURL: nil,
                settingsExisted: false,
                changedEvents: [],
                didChange: false
            )
        }

        var settings = try readSettings()
        guard settings["hooks"] != nil else {
            return ClaudeHookSettingsChange(
                settingsURL: settingsURL,
                backupURL: nil,
                settingsExisted: true,
                changedEvents: [],
                didChange: false
            )
        }

        var hooks = try hooksObject(in: settings)
        let changedEvents = removeAdderailHandlers(from: &hooks)

        guard changedEvents.isEmpty == false else {
            return ClaudeHookSettingsChange(
                settingsURL: settingsURL,
                backupURL: nil,
                settingsExisted: true,
                changedEvents: [],
                didChange: false
            )
        }

        settings["hooks"] = hooks

        return try apply(
            plan: ClaudeHookSettingsPlan(
                settings: settings,
                settingsExisted: true,
                changedEvents: changedEvents
            )
        )
    }

    func isInstalled() throws -> Bool {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return false
        }

        let settings = try readSettings()
        guard settings["hooks"] != nil else {
            return false
        }

        return containsAdderailHandlers(in: try hooksObject(in: settings))
    }

    private static let hookGroups = [
        ClaudeHookGroup(eventName: "UserPromptSubmit", matcher: nil),
        ClaudeHookGroup(eventName: "PreToolUse", matcher: "*"),
        ClaudeHookGroup(eventName: "PostToolBatch", matcher: nil),
        ClaudeHookGroup(eventName: "PostToolUseFailure", matcher: "*"),
        ClaudeHookGroup(eventName: "Stop", matcher: nil),
        ClaudeHookGroup(eventName: "StopFailure", matcher: "*"),
        ClaudeHookGroup(eventName: "SessionEnd", matcher: "")
    ]

    private func backupIfNeeded() throws -> URL? {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return nil
        }

        let backupURL = uniqueBackupURL()
        try FileManager.default.copyItem(at: settingsURL, to: backupURL)
        return backupURL
    }

    private func uniqueBackupURL() -> URL {
        let timestamp = Self.backupTimestampFormatter.string(from: Date())
        let basePath = "\(settingsURL.path).adderail-backup-\(timestamp)"
        var candidateURL = URL(fileURLWithPath: basePath)

        var suffix = 2
        while FileManager.default.fileExists(atPath: candidateURL.path) {
            candidateURL = URL(fileURLWithPath: "\(basePath)-\(suffix)")
            suffix += 1
        }

        return candidateURL
    }

    private static let backupTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private func readSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: settingsURL)
        if data.isEmpty {
            return [:]
        }

        let value = try JSONSerialization.jsonObject(with: data)
        guard let settings = value as? [String: Any] else {
            throw InstallerError.settingsMustBeObject(settingsURL)
        }

        return settings
    }

    private func write(settings: [String: Any]) throws {
        try FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsURL, options: .atomic)
    }

    private func hooksObject(in settings: [String: Any]) throws -> [String: Any] {
        guard let hooks = settings["hooks"] else {
            return [:]
        }

        guard let hookObject = hooks as? [String: Any] else {
            throw InstallerError.hooksMustBeObject(settingsURL)
        }

        return hookObject
    }

    private func eventGroups(for eventName: String, in hooks: [String: Any]) throws -> [[String: Any]] {
        guard let value = hooks[eventName] else {
            return []
        }

        guard let groups = value as? [[String: Any]] else {
            throw InstallerError.hookEventMustBeArray(eventName: eventName, settingsURL: settingsURL)
        }

        return groups
    }

    private func apply(plan: ClaudeHookSettingsPlan) throws -> ClaudeHookSettingsChange {
        let backupURL = try backupIfNeeded()
        try write(settings: plan.settings)

        return ClaudeHookSettingsChange(
            settingsURL: settingsURL,
            backupURL: backupURL,
            settingsExisted: plan.settingsExisted,
            changedEvents: plan.changedEvents,
            didChange: true
        )
    }

    private func containsAdderailHandlers(in hooks: [String: Any]) -> Bool {
        for value in hooks.values {
            guard let groups = value as? [[String: Any]] else {
                continue
            }

            for group in groups {
                guard let handlers = group["hooks"] as? [[String: Any]] else {
                    continue
                }

                if handlers.contains(where: isAdderailClaudeHandler) {
                    return true
                }
            }
        }

        return false
    }

    private func removeAdderailHandlers(from hooks: inout [String: Any]) -> [String] {
        var changedEvents: [String] = []

        for eventName in Array(hooks.keys) {
            guard let groups = hooks[eventName] as? [[String: Any]] else {
                continue
            }

            let nextGroups = groups.compactMap { group -> [String: Any]? in
                guard let handlers = group["hooks"] as? [[String: Any]] else {
                    return group
                }

                let nextHandlers = handlers.filter { isAdderailClaudeHandler($0) == false }
                if nextHandlers.isEmpty {
                    return nil
                }

                var nextGroup = group
                nextGroup["hooks"] = nextHandlers
                return nextGroup
            }

            guard nextGroups.count != groups.count || groupsContainChangedHandlers(groups, nextGroups) else {
                continue
            }

            changedEvents.append(eventName)

            if nextGroups.isEmpty {
                hooks.removeValue(forKey: eventName)
            } else {
                hooks[eventName] = nextGroups
            }
        }

        return changedEvents
    }

    private func isAdderailClaudeHandler(_ handler: [String: Any]) -> Bool {
        guard handler["type"] as? String == "command" else {
            return false
        }

        guard let args = handler["args"] as? [String], args == ["hook", "claude"] else {
            return false
        }

        let command = handler["command"] as? String ?? ""
        return URL(fileURLWithPath: command).lastPathComponent == "adderail"
    }

    private func groupsContainChangedHandlers(_ oldGroups: [[String: Any]], _ newGroups: [[String: Any]]) -> Bool {
        zip(oldGroups, newGroups).contains { oldGroup, newGroup in
            let oldHandlers = oldGroup["hooks"] as? [[String: Any]]
            let newHandlers = newGroup["hooks"] as? [[String: Any]]
            return oldHandlers?.count != newHandlers?.count
        }
    }
}

struct ClaudeHookSettingsPlan {
    let settings: [String: Any]
    let settingsExisted: Bool
    let changedEvents: [String]
}

struct ClaudeHookSettingsChange {
    let settingsURL: URL
    let backupURL: URL?
    let settingsExisted: Bool
    let changedEvents: [String]
    let didChange: Bool
}

private struct ClaudeHookGroup {
    let eventName: String
    let matcher: String?

    func dictionary(adderailURL: URL) -> [String: Any] {
        var group: [String: Any] = [
            "hooks": [
                [
                    "type": "command",
                    "command": adderailURL.path,
                    "args": ["hook", "claude"],
                    "timeout": 2
                ]
            ]
        ]

        if let matcher {
            group["matcher"] = matcher
        }

        return group
    }
}
