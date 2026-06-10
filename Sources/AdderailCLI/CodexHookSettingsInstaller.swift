import Foundation

struct CodexHookSettingsInstaller {
    let hooksURL: URL
    let adderailURL: URL

    static func defaultHooksURL() -> URL {
        let environment = ProcessInfo.processInfo.environment
        if let hooksPath = environment["ADDERAIL_CODEX_HOOKS_PATH"], hooksPath.isEmpty == false {
            return URL(fileURLWithPath: NSString(string: hooksPath).expandingTildeInPath)
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("hooks.json")
    }

    func prepareInstall() throws -> CodexHookSettingsPlan {
        let hooksFileExisted = FileManager.default.fileExists(atPath: hooksURL.path)
        var settings = try readSettings()
        var hooks = try hooksObject(in: settings)

        _ = removeAdderailHandlers(from: &hooks)

        for group in Self.hookGroups {
            var groups = try eventGroups(for: group.eventName, in: hooks)
            groups.append(group.dictionary(adderailURL: adderailURL))
            hooks[group.eventName] = groups
        }

        settings["hooks"] = hooks

        return CodexHookSettingsPlan(
            settings: settings,
            hooksFileExisted: hooksFileExisted,
            changedEvents: Self.hookGroups.map(\.eventName)
        )
    }

    func install() throws -> CodexHookSettingsChange {
        try install(preparedPlan: prepareInstall())
    }

    func install(preparedPlan: CodexHookSettingsPlan) throws -> CodexHookSettingsChange {
        try apply(plan: preparedPlan)
    }

    func uninstall() throws -> CodexHookSettingsChange {
        guard FileManager.default.fileExists(atPath: hooksURL.path) else {
            return CodexHookSettingsChange(
                hooksURL: hooksURL,
                backupURL: nil,
                hooksFileExisted: false,
                changedEvents: [],
                didChange: false
            )
        }

        var settings = try readSettings()
        guard settings["hooks"] != nil else {
            return CodexHookSettingsChange(
                hooksURL: hooksURL,
                backupURL: nil,
                hooksFileExisted: true,
                changedEvents: [],
                didChange: false
            )
        }

        var hooks = try hooksObject(in: settings)
        let changedEvents = removeAdderailHandlers(from: &hooks)

        guard changedEvents.isEmpty == false else {
            return CodexHookSettingsChange(
                hooksURL: hooksURL,
                backupURL: nil,
                hooksFileExisted: true,
                changedEvents: [],
                didChange: false
            )
        }

        settings["hooks"] = hooks

        return try apply(
            plan: CodexHookSettingsPlan(
                settings: settings,
                hooksFileExisted: true,
                changedEvents: changedEvents
            )
        )
    }

    func isInstalled() throws -> Bool {
        guard FileManager.default.fileExists(atPath: hooksURL.path) else {
            return false
        }

        let settings = try readSettings()
        guard settings["hooks"] != nil else {
            return false
        }

        return containsAdderailHandlers(in: try hooksObject(in: settings))
    }

    private static let hookGroups = [
        CodexHookGroup(eventName: "UserPromptSubmit", matcher: nil),
        CodexHookGroup(eventName: "PreToolUse", matcher: "*"),
        CodexHookGroup(eventName: "PostToolUse", matcher: "*"),
        CodexHookGroup(eventName: "Stop", matcher: nil)
    ]

    private func backupIfNeeded() throws -> URL? {
        guard FileManager.default.fileExists(atPath: hooksURL.path) else {
            return nil
        }

        let backupURL = uniqueBackupURL()
        try FileManager.default.copyItem(at: hooksURL, to: backupURL)
        return backupURL
    }

    private func uniqueBackupURL() -> URL {
        let timestamp = Self.backupTimestampFormatter.string(from: Date())
        let basePath = "\(hooksURL.path).adderail-backup-\(timestamp)"
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
        guard FileManager.default.fileExists(atPath: hooksURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: hooksURL)
        if data.isEmpty {
            return [:]
        }

        let value = try JSONSerialization.jsonObject(with: data)
        guard let settings = value as? [String: Any] else {
            throw InstallerError.codexHooksFileMustBeObject(hooksURL)
        }

        return settings
    }

    private func write(settings: [String: Any]) throws {
        try FileManager.default.createDirectory(
            at: hooksURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: hooksURL, options: .atomic)
    }

    private func hooksObject(in settings: [String: Any]) throws -> [String: Any] {
        guard let hooks = settings["hooks"] else {
            return [:]
        }

        guard let hookObject = hooks as? [String: Any] else {
            throw InstallerError.codexHooksMustBeObject(hooksURL)
        }

        return hookObject
    }

    private func eventGroups(for eventName: String, in hooks: [String: Any]) throws -> [[String: Any]] {
        guard let value = hooks[eventName] else {
            return []
        }

        guard let groups = value as? [[String: Any]] else {
            throw InstallerError.codexHookEventMustBeArray(eventName: eventName, hooksURL: hooksURL)
        }

        return groups
    }

    private func apply(plan: CodexHookSettingsPlan) throws -> CodexHookSettingsChange {
        let backupURL = try backupIfNeeded()
        try write(settings: plan.settings)

        return CodexHookSettingsChange(
            hooksURL: hooksURL,
            backupURL: backupURL,
            hooksFileExisted: plan.hooksFileExisted,
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

                if handlers.contains(where: isAdderailCodexHandler) {
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

                let nextHandlers = handlers.filter { isAdderailCodexHandler($0) == false }
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

    private func isAdderailCodexHandler(_ handler: [String: Any]) -> Bool {
        guard handler["type"] as? String == "command" else {
            return false
        }

        guard let command = handler["command"] as? String else {
            return false
        }

        guard command.hasSuffix(" hook codex") else {
            return false
        }

        let executable = String(command.dropLast(" hook codex".count))
        return URL(fileURLWithPath: unquotedCommandExecutable(executable)).lastPathComponent == "adderail"
    }

    private func unquotedCommandExecutable(_ executable: String) -> String {
        if executable.hasPrefix("'") && executable.hasSuffix("'") {
            return String(executable.dropFirst().dropLast())
        }

        return executable
    }

    private func groupsContainChangedHandlers(_ oldGroups: [[String: Any]], _ newGroups: [[String: Any]]) -> Bool {
        zip(oldGroups, newGroups).contains { oldGroup, newGroup in
            let oldHandlers = oldGroup["hooks"] as? [[String: Any]]
            let newHandlers = newGroup["hooks"] as? [[String: Any]]
            return oldHandlers?.count != newHandlers?.count
        }
    }
}

struct CodexHookSettingsPlan {
    let settings: [String: Any]
    let hooksFileExisted: Bool
    let changedEvents: [String]
}

struct CodexHookSettingsChange {
    let hooksURL: URL
    let backupURL: URL?
    let hooksFileExisted: Bool
    let changedEvents: [String]
    let didChange: Bool
}

private struct CodexHookGroup {
    let eventName: String
    let matcher: String?

    func dictionary(adderailURL: URL) -> [String: Any] {
        var group: [String: Any] = [
            "hooks": [
                [
                    "type": "command",
                    "command": "\(Self.shellQuoted(adderailURL.path)) hook codex",
                    "timeout": 2
                ]
            ]
        ]

        if let matcher {
            group["matcher"] = matcher
        }

        return group
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
