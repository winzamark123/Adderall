import AdderallShared
import ArgumentParser
import Foundation

enum CLICommand: Equatable {
    case begin(LeaseCommand)
    case heartbeat(LeaseCommand)
    case end(provider: String, sessionID: String)
    case status(json: Bool)
}

struct CLIParser {
    func parse(arguments: [String]) throws -> CLICommand {
        do {
            var command = try AdderallCommand.parseAsRoot(arguments)

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
        AdderallCommand.fullMessage(for: underlyingError)
    }

    var exitCode: Int32 {
        AdderallCommand.exitCode(for: underlyingError).rawValue
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

private struct AdderallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "adderall",
        abstract: "Keep a Mac awake while an agent lease is active.",
        subcommands: [
            Begin.self,
            Heartbeat.self,
            End.self,
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

private struct Status: ParsableCommand, CLICommandConvertible {
    static let configuration = CommandConfiguration(abstract: "Print controller status.")

    @Flag(name: .customLong("json"), help: "Print JSON output.")
    var json = false

    var command: CLICommand {
        .status(json: json)
    }
}
