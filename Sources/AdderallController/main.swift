import AdderallShared
import ArgumentParser
import Foundation

func runController() throws {
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
    let delegate = ControllerXPCListenerDelegate(service: service)
    let listener = NSXPCListener(machServiceName: options.machServiceName)
    listener.delegate = delegate
    listener.resume()

    print("adderall-controller listening on \(options.machServiceName)")
    RunLoop.main.run()
}

func printError(_ message: String) {
    let data = Data((message + "\n").utf8)
    FileHandle.standardError.write(data)
}

do {
    try runController()
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
