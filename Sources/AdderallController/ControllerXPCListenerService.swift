import Foundation
import ServiceLifecycle

actor ControllerXPCListenerService: Service {
    private let machServiceName: String
    private let listener: NSXPCListener
    private let delegate: ControllerXPCListenerDelegate

    init(machServiceName: String, service: ControllerXPCService) {
        self.machServiceName = machServiceName
        self.delegate = ControllerXPCListenerDelegate(service: service)
        self.listener = NSXPCListener(machServiceName: machServiceName)
        self.listener.delegate = delegate
    }

    func run() async throws {
        listener.resume()
        print("adderall-controller listening on \(machServiceName)")

        defer {
            listener.invalidate()
        }

        try await gracefulShutdown()
    }
}
