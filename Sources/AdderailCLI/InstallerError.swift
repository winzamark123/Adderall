import Foundation

enum InstallerError: LocalizedError {
    case missingCurrentExecutable
    case missingControllerBinary(URL)
    case launchctlFailed(arguments: [String], output: String)
    case controllerUnreachable(String)
    case settingsMustBeObject(URL)
    case hooksMustBeObject(URL)
    case hookEventMustBeArray(eventName: String, settingsURL: URL)
    case codexHooksFileMustBeObject(URL)
    case codexHooksMustBeObject(URL)
    case codexHookEventMustBeArray(eventName: String, hooksURL: URL)
    case piExtensionConflict(URL)

    var errorDescription: String? {
        switch self {
        case .missingCurrentExecutable:
            return "Could not locate the running adderail executable."
        case .missingControllerBinary(let url):
            return "Could not find executable adderail-controller next to adderail: \(url.path)"
        case .launchctlFailed(let arguments, let output):
            return "launchctl \(arguments.joined(separator: " ")) failed: \(output)"
        case .controllerUnreachable(let message):
            return "Controller did not become reachable after installation: \(message)"
        case .settingsMustBeObject(let url):
            return "Claude settings must be a JSON object: \(url.path)"
        case .hooksMustBeObject(let url):
            return "Claude settings hooks must be a JSON object: \(url.path)"
        case .hookEventMustBeArray(let eventName, let settingsURL):
            return "Claude settings hooks.\(eventName) must be an array: \(settingsURL.path)"
        case .codexHooksFileMustBeObject(let url):
            return "Codex hooks file must be a JSON object: \(url.path)"
        case .codexHooksMustBeObject(let url):
            return "Codex hooks must be a JSON object: \(url.path)"
        case .codexHookEventMustBeArray(let eventName, let hooksURL):
            return "Codex hooks.\(eventName) must be an array: \(hooksURL.path)"
        case .piExtensionConflict(let url):
            return "Pi extension path is not owned by Adderail: \(url.path)"
        }
    }
}
