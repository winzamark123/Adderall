import AdderailShared
@testable import AdderailCLI
import XCTest

final class CodexHookMapperTests: XCTestCase {
    func testUserPromptSubmitBeginsLease() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "turn_id": "turn-1",
          "hook_event_name": "UserPromptSubmit",
          "prompt": "build this"
        }
        """)

        XCTAssertEqual(command, .begin(LeaseCommand(provider: "codex", sessionID: "session-1")))
    }

    func testPreToolUseHeartbeatsWithLongToolTTL() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "turn_id": "turn-1",
          "hook_event_name": "PreToolUse",
          "tool_name": "Bash",
          "tool_input": {
            "command": "swift test"
          }
        }
        """)

        XCTAssertEqual(command, .heartbeat(LeaseCommand(provider: "codex", sessionID: "session-1", ttlSeconds: 900)))
    }

    func testPostToolUseHeartbeatsWithDefaultTTL() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "turn_id": "turn-1",
          "hook_event_name": "PostToolUse",
          "tool_name": "apply_patch",
          "tool_response": {}
        }
        """)

        XCTAssertEqual(command, .heartbeat(LeaseCommand(provider: "codex", sessionID: "session-1")))
    }

    func testStopShortensLease() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "turn_id": "turn-1",
          "hook_event_name": "Stop",
          "stop_hook_active": false
        }
        """)

        XCTAssertEqual(command, .heartbeat(LeaseCommand(provider: "codex", sessionID: "session-1", ttlSeconds: 60)))
    }

    func testSessionStartIsIgnored() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "hook_event_name": "SessionStart",
          "source": "startup"
        }
        """)

        XCTAssertNil(command)
    }

    private func map(_ json: String) throws -> CLICommand? {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try CodexHookMapper().mapping(from: data)?.command
    }
}
