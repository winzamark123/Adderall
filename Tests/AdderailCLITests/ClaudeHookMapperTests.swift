import AdderailShared
@testable import AdderailCLI
import XCTest

final class ClaudeHookMapperTests: XCTestCase {
    func testUserPromptSubmitBeginsLease() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "hook_event_name": "UserPromptSubmit",
          "prompt": "build this"
        }
        """)

        XCTAssertEqual(command, .begin(LeaseCommand(provider: "claude", sessionID: "session-1")))
    }

    func testPreToolUseHeartbeatsWithLongToolTimeout() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "hook_event_name": "PreToolUse",
          "tool_name": "Bash",
          "tool_input": {
            "command": "npm test",
            "timeout": 600000
          }
        }
        """)

        XCTAssertEqual(command, .heartbeat(LeaseCommand(provider: "claude", sessionID: "session-1", ttlSeconds: 660)))
    }

    func testPostToolBatchHeartbeatsOncePerBatch() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "hook_event_name": "PostToolBatch",
          "tool_calls": []
        }
        """)

        XCTAssertEqual(command, .heartbeat(LeaseCommand(provider: "claude", sessionID: "session-1")))
    }

    func testStopEndsLeaseWhenNoBackgroundWorkRemains() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "hook_event_name": "Stop",
          "background_tasks": [],
          "session_crons": []
        }
        """)

        XCTAssertEqual(command, .end(provider: "claude", sessionID: "session-1"))
    }

    func testStopEndShowsReleaseMessage() throws {
        let mapping = try mapWithMetadata("""
        {
          "session_id": "session-1",
          "hook_event_name": "Stop",
          "background_tasks": [],
          "session_crons": []
        }
        """)

        XCTAssertEqual(mapping?.command, .end(provider: "claude", sessionID: "session-1"))
        XCTAssertEqual(mapping?.systemMessage, "Released adderail (agent finished).")
    }

    func testStopRefreshesLeaseWhenBackgroundWorkRemains() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "hook_event_name": "Stop",
          "background_tasks": [
            {
              "id": "task-1",
              "type": "shell",
              "status": "running"
            }
          ],
          "session_crons": []
        }
        """)

        XCTAssertEqual(command, .heartbeat(LeaseCommand(provider: "claude", sessionID: "session-1")))
    }

    func testStopUsesShortTTLWhenBackgroundMetadataIsMissing() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "hook_event_name": "Stop"
        }
        """)

        XCTAssertEqual(command, .heartbeat(LeaseCommand(provider: "claude", sessionID: "session-1", ttlSeconds: 60)))
    }

    func testStopHeartbeatDoesNotShowReleaseMessage() throws {
        let mapping = try mapWithMetadata("""
        {
          "session_id": "session-1",
          "hook_event_name": "Stop"
        }
        """)

        XCTAssertEqual(mapping?.command, .heartbeat(LeaseCommand(provider: "claude", sessionID: "session-1", ttlSeconds: 60)))
        XCTAssertNil(mapping?.systemMessage)
    }

    func testSessionEndEndsLease() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "hook_event_name": "SessionEnd",
          "reason": "other"
        }
        """)

        XCTAssertEqual(command, .end(provider: "claude", sessionID: "session-1"))
    }

    func testSessionEndDoesNotShowReleaseMessage() throws {
        let mapping = try mapWithMetadata("""
        {
          "session_id": "session-1",
          "hook_event_name": "SessionEnd",
          "reason": "other"
        }
        """)

        XCTAssertEqual(mapping?.command, .end(provider: "claude", sessionID: "session-1"))
        XCTAssertNil(mapping?.systemMessage)
    }

    func testUnknownEventIsIgnored() throws {
        let command = try map("""
        {
          "session_id": "session-1",
          "hook_event_name": "Notification"
        }
        """)

        XCTAssertNil(command)
    }

    private func map(_ json: String) throws -> CLICommand? {
        try mapWithMetadata(json)?.command
    }

    private func mapWithMetadata(_ json: String) throws -> ClaudeHookMapping? {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try ClaudeHookMapper().mapping(from: data)
    }
}
