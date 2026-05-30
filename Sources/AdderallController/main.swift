import AdderallShared
import Foundation

func runController() throws {
    let options = try ControllerOptions(arguments: Array(CommandLine.arguments.dropFirst()))
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
} catch ControllerOptionsError.helpRequested {
    print(ControllerUsage.text)
} catch {
    printError(error.localizedDescription)
    exit(1)
}

struct ControllerOptions {
    let machServiceName: String

    init(arguments: [String]) throws {
        var machServiceName = adderallControllerMachServiceName
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "run":
                index += 1
            case "--mach-service":
                let valueIndex = index + 1

                guard valueIndex < arguments.count else {
                    throw ControllerOptionsError.missingValue(argument)
                }

                machServiceName = arguments[valueIndex]
                index += 2
            case "--help", "-h":
                throw ControllerOptionsError.helpRequested
            default:
                throw ControllerOptionsError.unknownOption(argument)
            }
        }

        self.machServiceName = machServiceName
    }
}

enum ControllerOptionsError: LocalizedError {
    case helpRequested
    case unknownOption(String)
    case missingValue(String)

    var errorDescription: String? {
        switch self {
        case .helpRequested:
            return ControllerUsage.text
        case .unknownOption(let option):
            return "Unknown controller option: \(option).\n\n\(ControllerUsage.text)"
        case .missingValue(let option):
            return "Missing value for \(option).\n\n\(ControllerUsage.text)"
        }
    }
}

enum ControllerUsage {
    static let text = """
    Usage:
      adderall-controller run [--mach-service <name>]
    """
}
