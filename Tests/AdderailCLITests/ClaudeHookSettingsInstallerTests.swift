@testable import AdderailCLI
import XCTest

final class ClaudeHookSettingsInstallerTests: XCTestCase {
    func testInstallPreservesExistingHooksAndAddsClaudeHooks() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")

        try writeJSON(
            [
                "hooks": [
                    "Notification": [
                        [
                            "matcher": "permission_prompt",
                            "hooks": [
                                ["type": "command", "command": "echo hi"]
                            ]
                        ]
                    ]
                ]
            ],
            to: settingsURL
        )

        let result = try ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderailURL: adderailURL).install()
        let settings = try readJSON(from: settingsURL)
        let hooks = try XCTUnwrap(settings["hooks"] as? [String: Any])

        XCTAssertNotNil(result.backupURL)
        XCTAssertEqual(result.changedEvents, [
            "UserPromptSubmit",
            "PreToolUse",
            "PostToolBatch",
            "PostToolUseFailure",
            "Stop",
            "StopFailure",
            "SessionEnd"
        ])
        XCTAssertEqual(adderailCommand(in: hooks, eventName: "UserPromptSubmit"), adderailURL.path)
        XCTAssertEqual(adderailArgs(in: hooks, eventName: "UserPromptSubmit"), ["hook", "claude"])
        XCTAssertEqual(existingNotificationCommand(in: hooks), "echo hi")
    }

    func testInstallIsIdempotent() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        let installer = ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderailURL: adderailURL)

        _ = try installer.install()
        _ = try installer.install()

        let settings = try readJSON(from: settingsURL)
        let hooks = try XCTUnwrap(settings["hooks"] as? [String: Any])
        XCTAssertEqual(adderailHandlerCount(in: hooks, eventName: "UserPromptSubmit"), 1)
        XCTAssertEqual(adderailHandlerCount(in: hooks, eventName: "PreToolUse"), 1)
    }

    func testUninstallRemovesOnlyAdderailHooks() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        let installer = ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderailURL: adderailURL)

        _ = try installer.install()
        var settings = try readJSON(from: settingsURL)
        var hooks = try XCTUnwrap(settings["hooks"] as? [String: Any])
        hooks["Notification"] = [
            [
                "hooks": [
                    ["type": "command", "command": "echo hi"]
                ]
            ]
        ]
        settings["hooks"] = hooks
        try writeJSON(settings, to: settingsURL)

        let result = try installer.uninstall()
        let uninstalledSettings = try readJSON(from: settingsURL)
        let uninstalledHooks = try XCTUnwrap(uninstalledSettings["hooks"] as? [String: Any])

        XCTAssertNotNil(result.backupURL)
        XCTAssertTrue(result.didChange)
        XCTAssertNil(uninstalledHooks["UserPromptSubmit"])
        XCTAssertEqual(existingNotificationCommand(in: uninstalledHooks), "echo hi")
    }

    func testUninstallDoesNotRewriteEmptyHooksWhenAdderailHooksAreAbsent() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        let originalData = Data(#"{"hooks":{}}"#.utf8)
        try originalData.write(to: settingsURL)

        let result = try ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderailURL: adderailURL).uninstall()
        let currentData = try Data(contentsOf: settingsURL)

        XCTAssertNil(result.backupURL)
        XCTAssertTrue(result.settingsExisted)
        XCTAssertFalse(result.didChange)
        XCTAssertEqual(result.changedEvents, [])
        XCTAssertEqual(currentData, originalData)
    }

    func testUninstallDoesNotRewriteExistingHooksWhenAdderailHooksAreAbsent() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        let originalData = Data("""
        {
          "hooks": {
            "UserPromptSubmit": [
              {
                "hooks": [
                  {
                    "type": "command",
                    "command": "printf hello"
                  }
                ]
              }
            ]
          }
        }
        """.utf8)
        try originalData.write(to: settingsURL)

        let result = try ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderailURL: adderailURL).uninstall()
        let currentData = try Data(contentsOf: settingsURL)

        XCTAssertNil(result.backupURL)
        XCTAssertTrue(result.settingsExisted)
        XCTAssertFalse(result.didChange)
        XCTAssertEqual(result.changedEvents, [])
        XCTAssertEqual(currentData, originalData)
    }

    func testUninstallPreservesHooksObjectWhenOnlyAdderailHooksAreRemoved() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        let installer = ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderailURL: adderailURL)

        _ = try installer.install()
        let result = try installer.uninstall()
        let settings = try readJSON(from: settingsURL)
        let hooks = try XCTUnwrap(settings["hooks"] as? [String: Any])

        XCTAssertNotNil(result.backupURL)
        XCTAssertTrue(result.didChange)
        XCTAssertTrue(hooks.isEmpty)
    }

    func testPrepareInstallRejectsInvalidSettingsWithoutBackup() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        try Data("[".utf8).write(to: settingsURL)

        XCTAssertThrowsError(try ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderailURL: adderailURL).prepareInstall())
        XCTAssertEqual(try backupURLs(for: settingsURL), [])
    }

    func testUninstallAllowsMissingSettingsFile() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("missing-settings.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")

        let result = try ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderailURL: adderailURL).uninstall()

        XCTAssertNil(result.backupURL)
        XCTAssertFalse(result.settingsExisted)
        XCTAssertFalse(result.didChange)
        XCTAssertFalse(FileManager.default.fileExists(atPath: settingsURL.path))
    }


    private func readJSON(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let value = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(value as? [String: Any])
    }

    private func writeJSON(_ object: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url)
    }

    private func backupURLs(for settingsURL: URL) throws -> [URL] {
        let directoryURL = settingsURL.deletingLastPathComponent()
        return try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ).filter { url in
            url.lastPathComponent.hasPrefix("\(settingsURL.lastPathComponent).adderail-backup-")
        }
    }

    private func adderailCommand(in hooks: [String: Any], eventName: String) -> String? {
        adderailHandler(in: hooks, eventName: eventName)?["command"] as? String
    }

    private func adderailArgs(in hooks: [String: Any], eventName: String) -> [String]? {
        adderailHandler(in: hooks, eventName: eventName)?["args"] as? [String]
    }

    private func adderailHandlerCount(in hooks: [String: Any], eventName: String) -> Int {
        handlers(in: hooks, eventName: eventName).filter { handler in
            handler["type"] as? String == "command"
                && handler["args"] as? [String] == ["hook", "claude"]
                && URL(fileURLWithPath: handler["command"] as? String ?? "").lastPathComponent == "adderail"
        }.count
    }

    private func adderailHandler(in hooks: [String: Any], eventName: String) -> [String: Any]? {
        handlers(in: hooks, eventName: eventName).first { handler in
            handler["type"] as? String == "command"
                && handler["args"] as? [String] == ["hook", "claude"]
                && URL(fileURLWithPath: handler["command"] as? String ?? "").lastPathComponent == "adderail"
        }
    }

    private func handlers(in hooks: [String: Any], eventName: String) -> [[String: Any]] {
        guard let groups = hooks[eventName] as? [[String: Any]] else {
            return []
        }

        return groups.flatMap { group in
            group["hooks"] as? [[String: Any]] ?? []
        }
    }

    private func existingNotificationCommand(in hooks: [String: Any]) -> String? {
        guard let groups = hooks["Notification"] as? [[String: Any]],
              let firstGroup = groups.first,
              let handlers = firstGroup["hooks"] as? [[String: Any]],
              let firstHandler = handlers.first else {
            return nil
        }

        return firstHandler["command"] as? String
    }
}
