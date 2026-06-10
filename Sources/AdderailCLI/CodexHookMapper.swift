import AdderailShared
import Foundation

struct CodexHookMapper {
    private let provider = "codex"
    private let stopTTLSeconds: TimeInterval = 60
    private let toolTTLSeconds: TimeInterval = 900

    func mapping(from data: Data) throws -> CodexHookMapping? {
        let input = try JSONDecoder().decode(CodexHookInput.self, from: data)
        guard let command = command(for: input) else {
            return nil
        }

        return CodexHookMapping(command: command)
    }

    private func command(for input: CodexHookInput) -> CLICommand? {
        switch input.hookEventName {
        case "UserPromptSubmit":
            return .begin(leaseCommand(sessionID: input.sessionID))
        case "PreToolUse":
            return .heartbeat(leaseCommand(sessionID: input.sessionID, ttlSeconds: toolTTLSeconds))
        case "PostToolUse":
            return .heartbeat(leaseCommand(sessionID: input.sessionID))
        case "Stop":
            return .heartbeat(leaseCommand(sessionID: input.sessionID, ttlSeconds: stopTTLSeconds))
        default:
            return nil
        }
    }

    private func leaseCommand(sessionID: String, ttlSeconds: TimeInterval = LeaseCommand.defaultTTLSeconds) -> LeaseCommand {
        LeaseCommand(provider: provider, sessionID: sessionID, ttlSeconds: ttlSeconds)
    }
}

struct CodexHookMapping: Equatable {
    let command: CLICommand
}

private struct CodexHookInput: Decodable {
    let sessionID: String
    let hookEventName: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case hookEventName = "hook_event_name"
    }
}
