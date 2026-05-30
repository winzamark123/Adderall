import Foundation

func run() throws {
    let command = try CLIParser().parse(arguments: Array(CommandLine.arguments.dropFirst()))
    let response = try ControllerClient().send(command)

    let requestSucceeded = response["success"] as? Bool ?? false

    if case .status = command {
        try printJSON(response)

        if requestSucceeded == false {
            exit(1)
        }

        return
    }

    if requestSucceeded == false {
        let message = response["error"] as? String ?? "Unknown controller error."
        throw RuntimeError(message)
    }
}

func printJSON(_ response: NSDictionary) throws {
    let data = try JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted, .sortedKeys])

    guard let output = String(data: data, encoding: .utf8) else {
        throw RuntimeError("Could not encode JSON response as UTF-8.")
    }

    print(output)
}

func printError(_ message: String) {
    let data = Data((message + "\n").utf8)
    FileHandle.standardError.write(data)
}

do {
    try run()
} catch let error as CLIParsingError {
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

struct RuntimeError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
