import AdderailShared
import ArgumentParser
import Foundation

enum CLICommand: Equatable {
    case begin(LeaseCommand)
    case heartbeat(LeaseCommand)
    case end(provider: String, sessionID: String)
    case hook(HookProvider)
    case install(IntegrationProvider)
    case uninstall(IntegrationProvider)
    case status(json: Bool)
}

enum HookProvider: Equatable {
    case claude
    case codex
}

enum IntegrationProvider: Equatable, CaseIterable {
    case claude
    case codex
    case pi
}

struct CLIParser {
    func parse(arguments: [String]) throws -> CLICommand {
        do {
            var command = try AdderailCommand.parseAsRoot(arguments)

            guard let cliCommand = command as? CLICommandConvertible else {
                if arguments.isEmpty {
                    throw CLIParserError.missingSubcommand
                }

                try command.run()
                throw CLIParserError.missingSubcommand
            }

            return cliCommand.command
        } catch {
            throw CLIParsingError(underlyingError: error)
        }
    }
}

struct CLIParsingError: Error {
    let underlyingError: Error

    var message: String {
        AdderailCommand.fullMessage(for: underlyingError)
    }

    var exitCode: Int32 {
        AdderailCommand.exitCode(for: underlyingError).rawValue
    }
}

private enum CLIParserError: LocalizedError {
    case missingSubcommand

    var errorDescription: String? {
        "Missing command."
    }
}

private protocol CLICommandConvertible {
    var command: CLICommand { get }
}

private struct AdderailCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "adderail",
        abstract: "Keep a Mac awake while an agent lease is active.",
        subcommands: [
            Begin.self,
            Heartbeat.self,
            End.self,
            Hook.self,
            Install.self,
            Uninstall.self,
            Status.self
        ]
    )
}

private struct LeaseOptions: ParsableArguments {
    @Option(help: "Agent provider name.")
    var provider: String

    @Option(name: .customLong("session"), help: "Agent session identifier.")
    var sessionID: String

    @Option(name: .customLong("ttl"), help: "Lease TTL in seconds.")
    var ttlSeconds: TimeInterval = LeaseCommand.defaultTTLSeconds

    var leaseCommand: LeaseCommand {
        LeaseCommand(provider: provider, sessionID: sessionID, ttlSeconds: ttlSeconds)
    }

    mutating func validate() throws {
        guard ttlSeconds > 0 else {
            throw ValidationError("TTL must be greater than 0.")
        }
    }
}

private struct SessionOptions: ParsableArguments {
    @Option(help: "Agent provider name.")
    var provider: String

    @Option(name: .customLong("session"), help: "Agent session identifier.")
    var sessionID: String
}

private struct Begin: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(abstract: "Begin an agent lease.")

    @OptionGroup var lease: LeaseOptions

    var command: CLICommand {
        .begin(lease.leaseCommand)
    }
}

private struct Heartbeat: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(abstract: "Refresh an agent lease.")

    @OptionGroup var lease: LeaseOptions

    var command: CLICommand {
        .heartbeat(lease.leaseCommand)
    }
}

private struct End: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(abstract: "End an agent lease.")

    @OptionGroup var session: SessionOptions

    var command: CLICommand {
        .end(provider: session.provider, sessionID: session.sessionID)
    }
}

private struct Hook: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Run from an agent hook.",
        subcommands: [ClaudeHook.self, CodexHook.self]
    )
}

private struct ClaudeHook: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(
        commandName: "claude",
        abstract: "Run from a Claude Code hook."
    )

    var command: CLICommand {
        .hook(.claude)
    }
}

private struct CodexHook: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(
        commandName: "codex",
        abstract: "Run from a Codex hook."
    )

    var command: CLICommand {
        .hook(.codex)
    }
}

private struct Install: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Install an agent integration.",
        subcommands: [InstallClaude.self, InstallCodex.self, InstallPi.self]
    )
}

private struct InstallClaude: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(
        commandName: "claude",
        abstract: "Install the Claude Code integration."
    )

    var command: CLICommand {
        .install(.claude)
    }
}

private struct InstallCodex: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(
        commandName: "codex",
        abstract: "Install the Codex integration."
    )

    var command: CLICommand {
        .install(.codex)
    }
}

private struct InstallPi: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(
        commandName: "pi",
        abstract: "Install the Pi integration."
    )

    var command: CLICommand {
        .install(.pi)
    }
}

private struct Uninstall: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Uninstall an agent integration.",
        subcommands: [UninstallClaude.self, UninstallCodex.self, UninstallPi.self]
    )
}

private struct UninstallClaude: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(
        commandName: "claude",
        abstract: "Uninstall the Claude Code integration."
    )

    var command: CLICommand {
        .uninstall(.claude)
    }
}

private struct UninstallCodex: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(
        commandName: "codex",
        abstract: "Uninstall the Codex integration."
    )

    var command: CLICommand {
        .uninstall(.codex)
    }
}

private struct UninstallPi: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(
        commandName: "pi",
        abstract: "Uninstall the Pi integration."
    )

    var command: CLICommand {
        .uninstall(.pi)
    }
}

private struct Status: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(abstract: "Print controller status.")

    @Flag(name: .customLong("json"), help: "Print JSON output.")
    var json = false

    var command: CLICommand {
        .status(json: json)
    }
}
