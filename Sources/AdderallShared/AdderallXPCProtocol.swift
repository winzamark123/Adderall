import Foundation

public let adderallControllerMachServiceName = "com.example.adderall.controller"

@objc public protocol AdderallControllerXPCProtocol {
    @objc(beginWithProvider:sessionID:ttlSeconds:reply:)
    func begin(provider: String, sessionID: String, ttlSeconds: NSNumber, reply: @escaping (NSDictionary) -> Void)

    @objc(heartbeatWithProvider:sessionID:ttlSeconds:reply:)
    func heartbeat(provider: String, sessionID: String, ttlSeconds: NSNumber, reply: @escaping (NSDictionary) -> Void)

    @objc(endWithProvider:sessionID:reply:)
    func end(provider: String, sessionID: String, reply: @escaping (NSDictionary) -> Void)

    @objc(statusWithReply:)
    func status(reply: @escaping (NSDictionary) -> Void)
}

public func makeControllerXPCInterface() -> NSXPCInterface {
    NSXPCInterface(with: AdderallControllerXPCProtocol.self)
}

public func successResponse(_ snapshot: ControllerSnapshot) -> NSDictionary {
    var response = snapshot.dictionary()
    response["success"] = true
    return response as NSDictionary
}

public func errorResponse(_ message: String) -> NSDictionary {
    [
        "success": false,
        "error": message
    ] as NSDictionary
}
