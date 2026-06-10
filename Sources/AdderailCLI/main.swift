import Foundation

func run() throws {
    let command = try CLIParser().parse(arguments: Array(CommandLine.arguments.dropFirst()))

    switch command {
    case .hook(.claude):
        runClaudeHook()
        return
    case .hook(.codex):
        runCodexHook()
        return
    case .install(let provider):
        let result = try IntegrationInstaller().install(provider)
        printInstallResult(result)
        return
    case .uninstall(let provider):
        let result = try IntegrationInstaller().uninstall(provider)
        printUninstallResult(result)
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

        guard let mapping = try ClaudeHookMapper().mapping(from: data) else {
            return
        }

        let response = try ControllerClient(timeout: 1).send(mapping.command)
        let requestSucceeded = response["success"] as? Bool ?? false

        if requestSucceeded == false {
            let message = response["error"] as? String ?? "Unknown controller error."
            logger?.log("Claude hook controller request failed: \(message)")
            return
        }

        if let systemMessage = mapping.systemMessage {
            try printClaudeHookSystemMessage(systemMessage)
        }
    } catch {
        logger?.log("Claude hook failed: \(error.localizedDescription)")
    }
}

func runCodexHook() {
    let logger = HookLogger.userDefault(provider: "codex")

    do {
        let data = FileHandle.standardInput.readDataToEndOfFile()

        guard data.isEmpty == false else {
            logger?.log("Codex hook received empty stdin.")
            return
        }

        guard let mapping = try CodexHookMapper().mapping(from: data) else {
            return
        }

        let response = try ControllerClient(timeout: 1).send(mapping.command)
        let requestSucceeded = response["success"] as? Bool ?? false

        if requestSucceeded == false {
            let message = response["error"] as? String ?? "Unknown controller error."
            logger?.log("Codex hook controller request failed: \(message)")
            return
        }
    } catch {
        logger?.log("Codex hook failed: \(error.localizedDescription)")
    }
}

func printInstallResult(_ result: IntegrationInstallResult) {
    switch result {
    case .claude(let result):
        printLaunchAgentInstallResult(result.launchAgentResult)

        if let backupURL = result.hookResult.backupURL {
            print("Backed up Claude settings: \(backupURL.path)")
        }

        print("Installed Claude Code hooks in: \(result.hookResult.settingsURL.path)")
        print("Next: restart Claude Code or run /hooks to verify.")
        print("Undo: adderail uninstall claude")
    case .codex(let result):
        printLaunchAgentInstallResult(result.launchAgentResult)

        if let backupURL = result.hookResult.backupURL {
            print("Backed up Codex hooks: \(backupURL.path)")
        }

        print("Installed Codex hooks in: \(result.hookResult.hooksURL.path)")
        print("Next: restart Codex, run /hooks, and trust the Adderail hooks.")
        print("Undo: adderail uninstall codex")
    case .pi(let result):
        printLaunchAgentInstallResult(result.launchAgentResult)

        if result.extensionResult.didChange {
            print("Installed Pi extension: \(result.extensionResult.extensionURL.path)")
        } else {
            print("Pi extension was already installed: \(result.extensionResult.extensionURL.path)")
        }

        print("Next: restart Pi or run /reload to load the extension.")
        print("Undo: adderail uninstall pi")
    }
}

func printUninstallResult(_ result: IntegrationUninstallResult) {
    switch result {
    case .claude(let result):
        if let backupURL = result.hookResult.backupURL {
            print("Backed up Claude settings: \(backupURL.path)")
        }

        if result.hookResult.didChange {
            print("Removed Adderail Claude Code hooks from: \(result.hookResult.settingsURL.path)")
        } else if result.hookResult.settingsExisted {
            print("Adderail Claude Code hooks were not installed in: \(result.hookResult.settingsURL.path)")
        } else {
            print("Claude settings file was not present: \(result.hookResult.settingsURL.path)")
        }

        printLaunchAgentUninstallResult(result.launchAgentResult)
    case .codex(let result):
        if let backupURL = result.hookResult.backupURL {
            print("Backed up Codex hooks: \(backupURL.path)")
        }

        if result.hookResult.didChange {
            print("Removed Adderail Codex hooks from: \(result.hookResult.hooksURL.path)")
        } else if result.hookResult.hooksFileExisted {
            print("Adderail Codex hooks were not installed in: \(result.hookResult.hooksURL.path)")
        } else {
            print("Codex hooks file was not present: \(result.hookResult.hooksURL.path)")
        }

        printLaunchAgentUninstallResult(result.launchAgentResult)
    case .pi(let result):
        if result.extensionResult.didChange {
            print("Removed Pi extension: \(result.extensionResult.extensionURL.path)")
        } else {
            print("Pi extension was not installed: \(result.extensionResult.extensionURL.path)")
        }

        printLaunchAgentUninstallResult(result.launchAgentResult)
    }
}

func printLaunchAgentInstallResult(_ result: LaunchAgentInstallResult) {
    print("Installed Adderail controller LaunchAgent: \(result.plistURL.path)")
    print("Installed adderail: \(result.cliURL.path)")
    print("Installed adderail-controller: \(result.controllerURL.path)")
}

func printLaunchAgentUninstallResult(_ result: LaunchAgentUninstallResult?) {
    guard let result else {
        print("Kept Adderail controller LaunchAgent because another integration is installed.")
        return
    }

    if result.removedPlist {
        print("Removed Adderail controller LaunchAgent: \(result.plistURL.path)")
    } else {
        print("Adderail controller LaunchAgent was not installed: \(result.plistURL.path)")
    }
}

func printClaudeHookSystemMessage(_ message: String) throws {
    try printJSON(["systemMessage": message] as NSDictionary)
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
