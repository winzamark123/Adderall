@testable import AdderailCLI
import XCTest

final class PiExtensionInstallerTests: XCTestCase {
    func testInstallWritesAdderailPiExtension() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let extensionURL = tempDirectoryURL.appendingPathComponent("adderail/index.ts")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")

        let result = try PiExtensionInstaller(extensionURL: extensionURL, adderailURL: adderailURL).install()
        let content = try String(contentsOf: extensionURL, encoding: .utf8)

        XCTAssertTrue(result.didChange)
        XCTAssertFalse(result.extensionExisted)
        XCTAssertTrue(content.contains("ADDERAIL_PI_EXTENSION"))
        XCTAssertTrue(content.contains("const ADDERAIL = \"\(adderailURL.path)\";"))
        XCTAssertTrue(content.contains("pi.on(\"agent_start\""))
        XCTAssertTrue(content.contains("pi.on(\"session_shutdown\""))
        XCTAssertTrue(content.contains("ctx.ui.setStatus(STATUS_KEY, \"awake\")"))
        XCTAssertTrue(content.contains("ctx.ui.notify(\"Released adderail (agent finished).\", \"info\")"))
    }

    func testInstallIsIdempotent() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let extensionURL = tempDirectoryURL.appendingPathComponent("adderail/index.ts")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        let installer = PiExtensionInstaller(extensionURL: extensionURL, adderailURL: adderailURL)

        _ = try installer.install()
        let result = try installer.install()

        XCTAssertFalse(result.didChange)
        XCTAssertTrue(result.extensionExisted)
        XCTAssertTrue(try installer.isInstalled())
    }

    func testInstallRejectsNonAdderailExtension() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let extensionURL = tempDirectoryURL.appendingPathComponent("adderail/index.ts")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        try FileManager.default.createDirectory(at: extensionURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "export default function other() {}".write(to: extensionURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try PiExtensionInstaller(extensionURL: extensionURL, adderailURL: adderailURL).install())
    }

    func testUninstallRemovesOnlyAdderailExtension() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let extensionURL = tempDirectoryURL.appendingPathComponent("adderail/index.ts")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")
        let installer = PiExtensionInstaller(extensionURL: extensionURL, adderailURL: adderailURL)

        _ = try installer.install()
        let result = try installer.uninstall()

        XCTAssertTrue(result.didChange)
        XCTAssertTrue(result.extensionExisted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: extensionURL.path))
    }

    func testUninstallAllowsMissingExtension() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        let extensionURL = tempDirectoryURL.appendingPathComponent("adderail/index.ts")
        let adderailURL = tempDirectoryURL.appendingPathComponent("bin/adderail")

        let result = try PiExtensionInstaller(extensionURL: extensionURL, adderailURL: adderailURL).uninstall()

        XCTAssertFalse(result.didChange)
        XCTAssertFalse(result.extensionExisted)
    }

}
