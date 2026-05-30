import AdderallShared
import Foundation

final class ControllerXPCService: NSObject, AdderallControllerXPCProtocol {
    private let state: ControllerState

    init(state: ControllerState) {
        self.state = state
    }

    func begin(provider: String, sessionID: String, ttlSeconds: NSNumber, reply: @escaping (NSDictionary) -> Void) {
        state.begin(LeaseCommand(provider: provider, sessionID: sessionID, ttlSeconds: ttlSeconds.doubleValue), reply: reply)
    }

    func heartbeat(provider: String, sessionID: String, ttlSeconds: NSNumber, reply: @escaping (NSDictionary) -> Void) {
        state.heartbeat(LeaseCommand(provider: provider, sessionID: sessionID, ttlSeconds: ttlSeconds.doubleValue), reply: reply)
    }

    func end(provider: String, sessionID: String, reply: @escaping (NSDictionary) -> Void) {
        state.end(provider: provider, sessionID: sessionID, reply: reply)
    }

    func status(reply: @escaping (NSDictionary) -> Void) {
        state.status(reply: reply)
    }
}

final class ControllerXPCListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service: ControllerXPCService

    init(service: ControllerXPCService) {
        self.service = service
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = makeControllerXPCInterface()
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}
