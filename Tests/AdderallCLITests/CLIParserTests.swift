import AdderallShared
@testable import AdderallCLI
import XCTest

final class CLIParserTests: XCTestCase {
    func testBeginParsesLeaseCommand() throws {
        let command = try CLIParser().parse(arguments: [
            "begin",
            "--provider", "claude",
            "--session", "abc",
            "--ttl", "30"
        ])

        XCTAssertEqual(command, .begin(LeaseCommand(provider: "claude", sessionID: "abc", ttlSeconds: 30)))
    }

    func testHeartbeatUsesDefaultTTL() throws {
        let command = try CLIParser().parse(arguments: [
            "heartbeat",
            "--provider", "codex",
            "--session", "def"
        ])

        XCTAssertEqual(command, .heartbeat(LeaseCommand(provider: "codex", sessionID: "def")))
    }

    func testEndParsesSessionCommand() throws {
        let command = try CLIParser().parse(arguments: [
            "end",
            "--provider", "claude",
            "--session", "abc"
        ])

        XCTAssertEqual(command, .end(provider: "claude", sessionID: "abc"))
    }

    func testHookParsesClaudeProvider() throws {
        let command = try CLIParser().parse(arguments: ["hook", "claude"])

        XCTAssertEqual(command, .hook(.claude))
    }

    func testInstallParsesClaudeProvider() throws {
        let command = try CLIParser().parse(arguments: ["install", "claude"])

        XCTAssertEqual(command, .install(.claude))
    }

    func testInstallParsesPiProvider() throws {
        let command = try CLIParser().parse(arguments: ["install", "pi"])

        XCTAssertEqual(command, .install(.pi))
    }

    func testUninstallParsesClaudeProvider() throws {
        let command = try CLIParser().parse(arguments: ["uninstall", "claude"])

        XCTAssertEqual(command, .uninstall(.claude))
    }

    func testUninstallParsesPiProvider() throws {
        let command = try CLIParser().parse(arguments: ["uninstall", "pi"])

        XCTAssertEqual(command, .uninstall(.pi))
    }

    func testStatusParsesJSONFlag() throws {
        let command = try CLIParser().parse(arguments: ["status", "--json"])

        XCTAssertEqual(command, .status(json: true))
    }

    func testStatusAllowsOmittedJSONFlag() throws {
        let command = try CLIParser().parse(arguments: ["status"])

        XCTAssertEqual(command, .status(json: false))
    }

    func testRejectsNonPositiveTTL() {
        XCTAssertThrowsError(try CLIParser().parse(arguments: [
            "begin",
            "--provider", "claude",
            "--session", "abc",
            "--ttl", "0"
        ])) { error in
            let parsingError = error as? CLIParsingError
            XCTAssertNotNil(parsingError)
            XCTAssertTrue(parsingError?.message.contains("TTL must be greater than 0.") == true)
        }
    }

    func testHelpExitsSuccessfully() {
        XCTAssertThrowsError(try CLIParser().parse(arguments: ["--help"])) { error in
            let parsingError = error as? CLIParsingError
            XCTAssertEqual(parsingError?.exitCode, 0)
            XCTAssertTrue(parsingError?.message.contains("USAGE: adderall") == true)
        }
    }
}
