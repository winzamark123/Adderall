@testable import AdderailCLI
import XCTest

final class CodexHookSettingsInstallerTests: XCTestCase {
    func testInstallPreservesExistingHooksAndAddsCodexHooks() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let hooksURL = tempDirectoryURL.appendingPathComponent("hooks.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")

        try writeJSON(
            [
                "hooks": [
                    "SessionStart": [
                        [
                            "matcher": "startup",
                            "hooks": [
                                ["type": "command", "command": "echo hi"]
                            ]
                        ]
                    ]
                ]
            ],
            to: hooksURL
        )

        let result = try CodexHookSettingsInstaller(hooksURL: hooksURL, adderailURL: adderailURL).install()
        let settings = try readJSON(from: hooksURL)
        let hooks = try XCTUnwrap(settings["hooks"] as? [String: Any])

        XCTAssertNotNil(result.backupURL)
        XCTAssertEqual(result.changedEvents, [
            "UserPromptSubmit",
            "PreToolUse",
            "PostToolUse",
            "Stop"
        ])
        XCTAssertEqual(adderailCommand(in: hooks, eventName: "UserPromptSubmit"), "'\(adderailURL.path)' hook codex")
        XCTAssertEqual(adderailMatcher(in: hooks, eventName: "PreToolUse"), "*")
        XCTAssertEqual(adderailMatcher(in: hooks, eventName: "PostToolUse"), "*")
        XCTAssertNil(adderailMatcher(in: hooks, eventName: "Stop"))
        XCTAssertEqual(existingSessionStartCommand(in: hooks), "echo hi")
    }

    func testInstallIsIdempotent() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let hooksURL = tempDirectoryURL.appendingPathComponent("hooks.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        let installer = CodexHookSettingsInstaller(hooksURL: hooksURL, adderailURL: adderailURL)

        _ = try installer.install()
        _ = try installer.install()

        let settings = try readJSON(from: hooksURL)
        let hooks = try XCTUnwrap(settings["hooks"] as? [String: Any])
        XCTAssertEqual(adderailHandlerCount(in: hooks, eventName: "UserPromptSubmit"), 1)
        XCTAssertEqual(adderailHandlerCount(in: hooks, eventName: "PreToolUse"), 1)
        XCTAssertTrue(try installer.isInstalled())
    }

    func testUninstallRemovesOnlyAdderailHooks() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let hooksURL = tempDirectoryURL.appendingPathComponent("hooks.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        let installer = CodexHookSettingsInstaller(hooksURL: hooksURL, adderailURL: adderailURL)

        _ = try installer.install()
        var settings = try readJSON(from: hooksURL)
        var hooks = try XCTUnwrap(settings["hooks"] as? [String: Any])
        hooks["SessionStart"] = [
            [
                "hooks": [
                    ["type": "command", "command": "echo hi"]
                ]
            ]
        ]
        settings["hooks"] = hooks
        try writeJSON(settings, to: hooksURL)

        let result = try installer.uninstall()
        let uninstalledSettings = try readJSON(from: hooksURL)
        let uninstalledHooks = try XCTUnwrap(uninstalledSettings["hooks"] as? [String: Any])

        XCTAssertNotNil(result.backupURL)
        XCTAssertTrue(result.didChange)
        XCTAssertNil(uninstalledHooks["UserPromptSubmit"])
        XCTAssertEqual(existingSessionStartCommand(in: uninstalledHooks), "echo hi")
    }

    func testUninstallDoesNotRewriteHooksWhenAdderailHooksAreAbsent() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let hooksURL = tempDirectoryURL.appendingPathComponent("hooks.json")
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
        try originalData.write(to: hooksURL)

        let result = try CodexHookSettingsInstaller(hooksURL: hooksURL, adderailURL: adderailURL).uninstall()
        let currentData = try Data(contentsOf: hooksURL)

        XCTAssertNil(result.backupURL)
        XCTAssertTrue(result.hooksFileExisted)
        XCTAssertFalse(result.didChange)
        XCTAssertEqual(result.changedEvents, [])
        XCTAssertEqual(currentData, originalData)
    }

    func testPrepareInstallRejectsInvalidHooksFileWithoutBackup() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let hooksURL = tempDirectoryURL.appendingPathComponent("hooks.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        try Data("[".utf8).write(to: hooksURL)

        XCTAssertThrowsError(try CodexHookSettingsInstaller(hooksURL: hooksURL, adderailURL: adderailURL).prepareInstall())
        XCTAssertEqual(try backupURLs(for: hooksURL), [])
    }

    func testUninstallAllowsMissingHooksFile() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let hooksURL = tempDirectoryURL.appendingPathComponent("missing-hooks.json")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")

        let result = try CodexHookSettingsInstaller(hooksURL: hooksURL, adderailURL: adderailURL).uninstall()

        XCTAssertNil(result.backupURL)
        XCTAssertFalse(result.hooksFileExisted)
        XCTAssertFalse(result.didChange)
        XCTAssertFalse(FileManager.default.fileExists(atPath: hooksURL.path))
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

    private func backupURLs(for hooksURL: URL) throws -> [URL] {
        let directoryURL = hooksURL.deletingLastPathComponent()
        return try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ).filter { url in
            url.lastPathComponent.hasPrefix("\(hooksURL.lastPathComponent).adderail-backup-")
        }
    }

    private func adderailCommand(in hooks: [String: Any], eventName: String) -> String? {
        adderailHandler(in: hooks, eventName: eventName)?["command"] as? String
    }

    private func adderailMatcher(in hooks: [String: Any], eventName: String) -> String? {
        guard let groups = hooks[eventName] as? [[String: Any]] else {
            return nil
        }

        return groups.first { group in
            let handlers = group["hooks"] as? [[String: Any]] ?? []
            return handlers.contains { handler in
                isAdderailHandler(handler)
            }
        }?["matcher"] as? String
    }

    private func adderailHandlerCount(in hooks: [String: Any], eventName: String) -> Int {
        handlers(in: hooks, eventName: eventName).filter(isAdderailHandler).count
    }

    private func adderailHandler(in hooks: [String: Any], eventName: String) -> [String: Any]? {
        handlers(in: hooks, eventName: eventName).first(where: isAdderailHandler)
    }

    private func isAdderailHandler(_ handler: [String: Any]) -> Bool {
        guard handler["type"] as? String == "command" else {
            return false
        }

        let command = handler["command"] as? String ?? ""
        return command.hasSuffix(" hook codex") && command.contains("adderail")
    }

    private func handlers(in hooks: [String: Any], eventName: String) -> [[String: Any]] {
        guard let groups = hooks[eventName] as? [[String: Any]] else {
            return []
        }

        return groups.flatMap { group in
            group["hooks"] as? [[String: Any]] ?? []
        }
    }

    private func existingSessionStartCommand(in hooks: [String: Any]) -> String? {
        guard let groups = hooks["SessionStart"] as? [[String: Any]],
              let firstGroup = groups.first,
              let handlers = firstGroup["hooks"] as? [[String: Any]],
              let firstHandler = handlers.first else {
            return nil
        }

        return firstHandler["command"] as? String
    }
}
