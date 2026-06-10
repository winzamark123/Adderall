import AdderailShared
import Foundation

struct ControllerClient {
    let machServiceName: String
    let timeout: TimeInterval

    init(machServiceName: String = adderailControllerMachServiceName, timeout: TimeInterval = 3) {
        self.machServiceName = machServiceName
        self.timeout = timeout
    }

    func send(_ command: CLICommand) throws -> NSDictionary {
        let connection = NSXPCConnection(machServiceName: machServiceName, options: [])
        connection.remoteObjectInterface = makeControllerXPCInterface()
        connection.resume()
        defer {
            connection.invalidate()
        }

        let semaphore = DispatchSemaphore(value: 0)
        let responseBox = ResponseBox()

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            responseBox.response = errorResponse(error.localizedDescription)
            semaphore.signal()
        }

        guard let controller = proxy as? AdderailControllerXPCProtocol else {
            throw ControllerClientError.invalidRemoteProxy
        }

        switch command {
        case .begin(let leaseCommand):
            controller.begin(
                provider: leaseCommand.provider,
                sessionID: leaseCommand.sessionID,
                ttlSeconds: NSNumber(value: leaseCommand.ttlSeconds)
            ) { response in
                responseBox.response = response
                semaphore.signal()
            }
        case .heartbeat(let leaseCommand):
            controller.heartbeat(
                provider: leaseCommand.provider,
                sessionID: leaseCommand.sessionID,
                ttlSeconds: NSNumber(value: leaseCommand.ttlSeconds)
            ) { response in
                responseBox.response = response
                semaphore.signal()
            }
        case .end(let provider, let sessionID):
            controller.end(provider: provider, sessionID: sessionID) { response in
                responseBox.response = response
                semaphore.signal()
            }
        case .hook, .install, .uninstall:
            throw ControllerClientError.unsendableCommand
        case .status:
            controller.status { response in
                responseBox.response = response
                semaphore.signal()
            }
        }

        let deadline = DispatchTime.now() + timeout
        guard semaphore.wait(timeout: deadline) == .success else {
            throw ControllerClientError.timeout
        }

        guard let response = responseBox.response else {
            throw ControllerClientError.emptyResponse
        }

        return response
    }
}

private final class ResponseBox {
    var response: NSDictionary?
}

enum ControllerClientError: LocalizedError {
    case invalidRemoteProxy
    case timeout
    case emptyResponse
    case unsendableCommand

    var errorDescription: String? {
        switch self {
        case .invalidRemoteProxy:
            return "Could not create an XPC proxy for the Adderail controller."
        case .timeout:
            return "Timed out waiting for the Adderail controller. Is the LaunchAgent loaded?"
        case .emptyResponse:
            return "The Adderail controller returned no response."
        case .unsendableCommand:
            return "This command cannot be sent directly to the Adderail controller."
        }
    }
}
