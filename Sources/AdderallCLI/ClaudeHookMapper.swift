import AdderallShared
import Foundation

struct ClaudeHookMapper {
    private let provider = "claude"
    private let staleStopTTLSeconds: TimeInterval = 60
    private let toolTimeoutBufferSeconds: TimeInterval = 60

    func command(from data: Data) throws -> CLICommand? {
        let input = try JSONDecoder().decode(ClaudeHookInput.self, from: data)
        return command(for: input)
    }

    private func command(for input: ClaudeHookInput) -> CLICommand? {
        switch input.hookEventName {
        case "UserPromptSubmit":
            return .begin(leaseCommand(sessionID: input.sessionID))
        case "PreToolUse":
            return .heartbeat(leaseCommand(sessionID: input.sessionID, ttlSeconds: toolTTLSeconds(for: input)))
        case "PostToolUse", "PostToolBatch", "PostToolUseFailure":
            return .heartbeat(leaseCommand(sessionID: input.sessionID))
        case "Stop":
            return stopCommand(for: input)
        case "StopFailure", "SessionEnd":
            return .end(provider: provider, sessionID: input.sessionID)
        default:
            return nil
        }
    }

    private func stopCommand(for input: ClaudeHookInput) -> CLICommand {
        guard let backgroundTasks = input.backgroundTasks, let sessionCrons = input.sessionCrons else {
            return .heartbeat(leaseCommand(sessionID: input.sessionID, ttlSeconds: staleStopTTLSeconds))
        }

        if backgroundTasks.isEmpty && sessionCrons.isEmpty {
            return .end(provider: provider, sessionID: input.sessionID)
        }

        return .heartbeat(leaseCommand(sessionID: input.sessionID))
    }

    private func toolTTLSeconds(for input: ClaudeHookInput) -> TimeInterval {
        guard let timeoutMilliseconds = input.toolInput?.timeoutMilliseconds, timeoutMilliseconds > 0 else {
            return LeaseCommand.defaultTTLSeconds
        }

        let timeoutSeconds = ceil(timeoutMilliseconds / 1000)
        return max(LeaseCommand.defaultTTLSeconds, timeoutSeconds + toolTimeoutBufferSeconds)
    }

    private func leaseCommand(sessionID: String, ttlSeconds: TimeInterval = LeaseCommand.defaultTTLSeconds) -> LeaseCommand {
        LeaseCommand(provider: provider, sessionID: sessionID, ttlSeconds: ttlSeconds)
    }
}

private struct ClaudeHookInput: Decodable {
    let sessionID: String
    let hookEventName: String
    let toolInput: ClaudeToolInput?
    let backgroundTasks: [ClaudeHookArrayElement]?
    let sessionCrons: [ClaudeHookArrayElement]?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case hookEventName = "hook_event_name"
        case toolInput = "tool_input"
        case backgroundTasks = "background_tasks"
        case sessionCrons = "session_crons"
    }
}

private struct ClaudeToolInput: Decodable {
    let timeoutMilliseconds: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case timeoutMilliseconds = "timeout"
    }
}

private struct ClaudeHookArrayElement: Decodable {}
