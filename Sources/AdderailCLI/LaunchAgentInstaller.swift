import AdderailShared
import Darwin
import Foundation

struct LaunchAgentInstaller {
    private let fileManager: FileManager
    private let label = "com.adderail.controller"
    private let controllerExecutableName = "adderail-controller"
    private let cliExecutableName = "adderail"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var installBinURL: URL {
        applicationSupportURL
            .appendingPathComponent("Adderail", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
    }

    var cliURL: URL {
        installBinURL.appendingPathComponent(cliExecutableName)
    }

    var controllerURL: URL {
        installBinURL.appendingPathComponent(controllerExecutableName)
    }

    var plistURL: URL {
        libraryURL
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    func install() throws -> LaunchAgentInstallResult {
        let currentExecutableURL = try currentCLIExecutableURL()
        let sourceDirectoryURL = currentExecutableURL.deletingLastPathComponent()
        let sourceControllerURL = sourceDirectoryURL.appendingPathComponent(controllerExecutableName)

        guard fileManager.isExecutableFile(atPath: sourceControllerURL.path) else {
            throw InstallerError.missingControllerBinary(sourceControllerURL)
        }

        try stopIfLoaded()
        try fileManager.createDirectory(at: installBinURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try copyExecutableIfNeeded(from: currentExecutableURL, to: cliURL)
        try copyExecutableIfNeeded(from: sourceControllerURL, to: controllerURL)
        try writeLaunchAgentPlist()
        _ = try runLaunchctl(["bootstrap", launchctlDomain, plistURL.path])
        try waitForController()

        return LaunchAgentInstallResult(
            plistURL: plistURL,
            cliURL: cliURL,
            controllerURL: controllerURL
        )
    }

    func uninstall() throws -> LaunchAgentUninstallResult {
        try stopIfLoaded()

        let removedPlist: Bool
        if fileManager.fileExists(atPath: plistURL.path) {
            try fileManager.removeItem(at: plistURL)
            removedPlist = true
        } else {
            removedPlist = false
        }

        return LaunchAgentUninstallResult(plistURL: plistURL, removedPlist: removedPlist)
    }

    private var libraryURL: URL {
        fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
    }

    private var applicationSupportURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private var launchctlDomain: String {
        "gui/\(getuid())"
    }

    private func currentCLIExecutableURL() throws -> URL {
        guard let executableURL = Bundle.main.executableURL else {
            throw InstallerError.missingCurrentExecutable
        }

        return executableURL.resolvingSymlinksInPath()
    }

    private func copyExecutableIfNeeded(from sourceURL: URL, to destinationURL: URL) throws {
        let resolvedSourceURL = sourceURL.resolvingSymlinksInPath()
        let resolvedDestinationURL = destinationURL.resolvingSymlinksInPath()

        if resolvedSourceURL.path == resolvedDestinationURL.path {
            return
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
    }

    private func writeLaunchAgentPlist() throws {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [controllerURL.path, "run"],
            "MachServices": [adderailControllerMachServiceName: true],
            "RunAtLoad": true
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    private func stopIfLoaded() throws {
        _ = try runLaunchctl(["bootout", launchctlDomain, plistURL.path], check: false)
        _ = try runLaunchctl(["bootout", "\(launchctlDomain)/\(label)"], check: false)
    }

    private func waitForController() throws {
        var lastError = "Controller did not respond."

        for _ in 0..<20 {
            do {
                let response = try ControllerClient(timeout: 1).send(.status(json: false))
                if response["success"] as? Bool == true {
                    return
                }

                lastError = response["error"] as? String ?? "Controller status returned an unsuccessful response."
            } catch {
                lastError = error.localizedDescription
            }

            Thread.sleep(forTimeInterval: 0.25)
        }

        throw InstallerError.controllerUnreachable(lastError)
    }

    private func runLaunchctl(_ arguments: [String], check: Bool = true) throws -> ProcessResult {
        let result = try ProcessRunner.run(executablePath: "/bin/launchctl", arguments: arguments)

        if check && result.exitCode != 0 {
            throw InstallerError.launchctlFailed(arguments: arguments, output: result.combinedOutput)
        }

        return result
    }
}

struct LaunchAgentInstallResult {
    let plistURL: URL
    let cliURL: URL
    let controllerURL: URL
}

struct LaunchAgentUninstallResult {
    let plistURL: URL
    let removedPlist: Bool
}

private struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var combinedOutput: String {
        let output = [stdout, stderr]
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")

        if output.isEmpty {
            return "launchctl exited with status \(exitCode)."
        }

        return output
    }
}

private enum ProcessRunner {
    static func run(executablePath: String, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
