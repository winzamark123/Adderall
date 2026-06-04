@testable import AdderallCLI
import XCTest

final class ClaudeHookSettingsInstallerTests: XCTestCase {
    func testInstallPreservesExistingHooksAndAddsClaudeHooks() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")

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

        let result = try ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderallURL: adderallURL).install()
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
        XCTAssertEqual(adderallCommand(in: hooks, eventName: "UserPromptSubmit"), adderallURL.path)
        XCTAssertEqual(adderallArgs(in: hooks, eventName: "UserPromptSubmit"), ["hook", "claude"])
        XCTAssertEqual(existingNotificationCommand(in: hooks), "echo hi")
    }

    func testInstallIsIdempotent() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")
        let installer = ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderallURL: adderallURL)

        _ = try installer.install()
        _ = try installer.install()

        let settings = try readJSON(from: settingsURL)
        let hooks = try XCTUnwrap(settings["hooks"] as? [String: Any])
        XCTAssertEqual(adderallHandlerCount(in: hooks, eventName: "UserPromptSubmit"), 1)
        XCTAssertEqual(adderallHandlerCount(in: hooks, eventName: "PreToolUse"), 1)
    }

    func testUninstallRemovesOnlyAdderallHooks() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")
        let installer = ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderallURL: adderallURL)

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

    func testUninstallDoesNotRewriteEmptyHooksWhenAdderallHooksAreAbsent() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")
        let originalData = Data(#"{"hooks":{}}"#.utf8)
        try originalData.write(to: settingsURL)

        let result = try ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderallURL: adderallURL).uninstall()
        let currentData = try Data(contentsOf: settingsURL)

        XCTAssertNil(result.backupURL)
        XCTAssertTrue(result.settingsExisted)
        XCTAssertFalse(result.didChange)
        XCTAssertEqual(result.changedEvents, [])
        XCTAssertEqual(currentData, originalData)
    }

    func testUninstallDoesNotRewriteExistingHooksWhenAdderallHooksAreAbsent() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")
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

        let result = try ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderallURL: adderallURL).uninstall()
        let currentData = try Data(contentsOf: settingsURL)

        XCTAssertNil(result.backupURL)
        XCTAssertTrue(result.settingsExisted)
        XCTAssertFalse(result.didChange)
        XCTAssertEqual(result.changedEvents, [])
        XCTAssertEqual(currentData, originalData)
    }

    func testUninstallPreservesHooksObjectWhenOnlyAdderallHooksAreRemoved() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("settings.json")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")
        let installer = ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderallURL: adderallURL)

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
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")
        try Data("[".utf8).write(to: settingsURL)

        XCTAssertThrowsError(try ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderallURL: adderallURL).prepareInstall())
        XCTAssertEqual(try backupURLs(for: settingsURL), [])
    }

    func testUninstallAllowsMissingSettingsFile() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let settingsURL = tempDirectoryURL.appendingPathComponent("missing-settings.json")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")

        let result = try ClaudeHookSettingsInstaller(settingsURL: settingsURL, adderallURL: adderallURL).uninstall()

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
            url.lastPathComponent.hasPrefix("\(settingsURL.lastPathComponent).adderall-backup-")
        }
    }

    private func adderallCommand(in hooks: [String: Any], eventName: String) -> String? {
        adderallHandler(in: hooks, eventName: eventName)?["command"] as? String
    }

    private func adderallArgs(in hooks: [String: Any], eventName: String) -> [String]? {
        adderallHandler(in: hooks, eventName: eventName)?["args"] as? [String]
    }

    private func adderallHandlerCount(in hooks: [String: Any], eventName: String) -> Int {
        handlers(in: hooks, eventName: eventName).filter { handler in
            handler["type"] as? String == "command"
                && handler["args"] as? [String] == ["hook", "claude"]
                && URL(fileURLWithPath: handler["command"] as? String ?? "").lastPathComponent == "adderall"
        }.count
    }

    private func adderallHandler(in hooks: [String: Any], eventName: String) -> [String: Any]? {
        handlers(in: hooks, eventName: eventName).first { handler in
            handler["type"] as? String == "command"
                && handler["args"] as? [String] == ["hook", "claude"]
                && URL(fileURLWithPath: handler["command"] as? String ?? "").lastPathComponent == "adderall"
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
