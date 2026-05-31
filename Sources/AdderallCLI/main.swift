import Foundation

func run() throws {
    let command = try CLIParser().parse(arguments: Array(CommandLine.arguments.dropFirst()))

    switch command {
    case .hook(.claude):
        runClaudeHook()
        return
    case .install(.claude):
        let result = try ClaudeIntegrationInstaller().install()
        printClaudeInstallResult(result)
        return
    case .uninstall(.claude):
        let result = try ClaudeIntegrationInstaller().uninstall()
        printClaudeUninstallResult(result)
        return
    default:
        break
    }

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

func runClaudeHook() {
    let logger = HookLogger.userDefault()

    do {
        let data = FileHandle.standardInput.readDataToEndOfFile()

        guard data.isEmpty == false else {
            logger?.log("Claude hook received empty stdin.")
            return
        }

        guard let command = try ClaudeHookMapper().command(from: data) else {
            return
        }

        let response = try ControllerClient(timeout: 1).send(command)
        let requestSucceeded = response["success"] as? Bool ?? false

        if requestSucceeded == false {
            let message = response["error"] as? String ?? "Unknown controller error."
            logger?.log("Claude hook controller request failed: \(message)")
        }
    } catch {
        logger?.log("Claude hook failed: \(error.localizedDescription)")
    }
}

func printClaudeInstallResult(_ result: ClaudeIntegrationInstallResult) {
    print("Installed Adderall controller LaunchAgent: \(result.launchAgentResult.plistURL.path)")
    print("Installed adderall: \(result.launchAgentResult.cliURL.path)")
    print("Installed adderall-controller: \(result.launchAgentResult.controllerURL.path)")

    if let backupURL = result.hookResult.backupURL {
        print("Backed up Claude settings: \(backupURL.path)")
    }

    print("Installed Claude Code hooks in: \(result.hookResult.settingsURL.path)")
    print("Next: restart Claude Code or run /hooks to verify.")
    print("Undo: adderall uninstall claude")
}

func printClaudeUninstallResult(_ result: ClaudeIntegrationUninstallResult) {
    if let backupURL = result.hookResult.backupURL {
        print("Backed up Claude settings: \(backupURL.path)")
    }

    if result.hookResult.didChange {
        print("Removed Adderall Claude Code hooks from: \(result.hookResult.settingsURL.path)")
    } else if result.hookResult.settingsExisted {
        print("Adderall Claude Code hooks were not installed in: \(result.hookResult.settingsURL.path)")
    } else {
        print("Claude settings file was not present: \(result.hookResult.settingsURL.path)")
    }

    if result.launchAgentResult.removedPlist {
        print("Removed Adderall controller LaunchAgent: \(result.launchAgentResult.plistURL.path)")
    } else {
        print("Adderall controller LaunchAgent was not installed: \(result.launchAgentResult.plistURL.path)")
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
