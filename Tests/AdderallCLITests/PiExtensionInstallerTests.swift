@testable import AdderallCLI
import XCTest

final class PiExtensionInstallerTests: XCTestCase {
    func testInstallWritesAdderallPiExtension() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let extensionURL = tempDirectoryURL.appendingPathComponent("adderall/index.ts")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")

        let result = try PiExtensionInstaller(extensionURL: extensionURL, adderallURL: adderallURL).install()
        let content = try String(contentsOf: extensionURL, encoding: .utf8)

        XCTAssertTrue(result.didChange)
        XCTAssertFalse(result.extensionExisted)
        XCTAssertTrue(content.contains("ADDERALL_PI_EXTENSION"))
        XCTAssertTrue(content.contains("const ADDERALL = \"\(adderallURL.path)\";"))
        XCTAssertTrue(content.contains("pi.on(\"agent_start\""))
        XCTAssertTrue(content.contains("pi.on(\"session_shutdown\""))
        XCTAssertTrue(content.contains("ctx.ui.setStatus(STATUS_KEY, \"awake\")"))
        XCTAssertTrue(content.contains("ctx.ui.notify(\"Released adderall (agent finished).\", \"info\")"))
    }

    func testInstallIsIdempotent() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let extensionURL = tempDirectoryURL.appendingPathComponent("adderall/index.ts")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")
        let installer = PiExtensionInstaller(extensionURL: extensionURL, adderallURL: adderallURL)

        _ = try installer.install()
        let result = try installer.install()

        XCTAssertFalse(result.didChange)
        XCTAssertTrue(result.extensionExisted)
        XCTAssertTrue(try installer.isInstalled())
    }

    func testInstallRejectsNonAdderallExtension() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let extensionURL = tempDirectoryURL.appendingPathComponent("adderall/index.ts")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")
        try FileManager.default.createDirectory(at: extensionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "export default function other() {}".write(to: extensionURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try PiExtensionInstaller(extensionURL: extensionURL, adderallURL: adderallURL).install())
    }

    func testUninstallRemovesOnlyAdderallExtension() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let extensionURL = tempDirectoryURL.appendingPathComponent("adderall/index.ts")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")
        let installer = PiExtensionInstaller(extensionURL: extensionURL, adderallURL: adderallURL)

        _ = try installer.install()
        let result = try installer.uninstall()

        XCTAssertTrue(result.didChange)
        XCTAssertTrue(result.extensionExisted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: extensionURL.path))
    }

    func testUninstallAllowsMissingExtension() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let extensionURL = tempDirectoryURL.appendingPathComponent("adderall/index.ts")
        let adderallURL = tempDirectoryURL.appendingPathComponent("bin/adderall")

        let result = try PiExtensionInstaller(extensionURL: extensionURL, adderallURL: adderallURL).uninstall()

        XCTAssertFalse(result.didChange)
        XCTAssertFalse(result.extensionExisted)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}
