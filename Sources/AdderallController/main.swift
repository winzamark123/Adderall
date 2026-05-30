import AdderallShared
import ArgumentParser
import Foundation
import Logging
import ServiceLifecycle

func runController() async throws {
    let options: ControllerOptions

    do {
        options = try ControllerOptions.parse(Array(CommandLine.arguments.dropFirst()))
    } catch {
        throw ControllerParsingError(underlyingError: error)
    }

    let snapshotStore = try SnapshotStore.userDefault()
    let state = ControllerState(
        snapshotStore: snapshotStore,
        awakeAssertionController: AwakeAssertionController()
    )
    let service = ControllerXPCService(state: state)
    let listenerService = ControllerXPCListenerService(
        machServiceName: options.machServiceName,
        service: service
    )
    let serviceGroup = ServiceGroup(
        services: [listenerService],
        gracefulShutdownSignals: [.sigterm, .sigint],
        logger: Logger(label: "com.example.adderall.controller")
    )

    try await serviceGroup.run()
}

func printError(_ message: String) {
    let data = Data((message + "\n").utf8)
    FileHandle.standardError.write(data)
}

do {
    try await runController()
} catch let error as ControllerParsingError {
    if error.exitCode == 0 {
        print(error.message)
    } else {
        printError(error.message)
    }

    exit(error.exitCode)
} catch {
    printError(error.localizedDescription)
    exit(1)
}

struct ControllerParsingError: Error {
    let underlyingError: Error

    var message: String {
        ControllerOptions.fullMessage(for: underlyingError)
    }

    var exitCode: Int32 {
        ControllerOptions.exitCode(for: underlyingError).rawValue
    }
}

struct ControllerOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "adderall-controller",
        abstract: "Run the Adderall controller service."
    )

    @Argument(help: "Controller command.")
    var command: ControllerCommand = .run

    @Option(name: .customLong("mach-service"), help: "Mach service name.")
    var machServiceName = adderallControllerMachServiceName
}

enum ControllerCommand: String, ExpressibleByArgument {
    case run
}
