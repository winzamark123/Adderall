import AdderallShared
import Foundation

struct ControllerClient {
    let machServiceName: String
    let timeout: TimeInterval

    init(machServiceName: String = adderallControllerMachServiceName, timeout: TimeInterval = 3) {
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

        guard let controller = proxy as? AdderallControllerXPCProtocol else {
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

    var errorDescription: String? {
        switch self {
        case .invalidRemoteProxy:
            return "Could not create an XPC proxy for the Adderall controller."
        case .timeout:
            return "Timed out waiting for the Adderall controller. Is the LaunchAgent loaded?"
        case .emptyResponse:
            return "The Adderall controller returned no response."
        }
    }
}
