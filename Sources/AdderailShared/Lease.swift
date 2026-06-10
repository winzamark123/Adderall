import Foundation

public struct LeaseKey: Codable, Equatable, Hashable, Sendable {
    public let provider: String
    public let sessionID: String

    public init(provider: String, sessionID: String) {
        self.provider = provider
        self.sessionID = sessionID
    }
}

public struct Lease: Codable, Equatable, Sendable {
    public let provider: String
    public let sessionID: String
    public let startedAt: Date
    public let lastHeartbeatAt: Date
    public let expiresAt: Date

    public var key: LeaseKey {
        LeaseKey(provider: provider, sessionID: sessionID)
    }

    public init(provider: String, sessionID: String, startedAt: Date, lastHeartbeatAt: Date, expiresAt: Date) {
        self.provider = provider
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.lastHeartbeatAt = lastHeartbeatAt
        self.expiresAt = expiresAt
    }

    public func refreshed(at now: Date, ttlSeconds: TimeInterval) -> Lease {
        Lease(
            provider: provider,
            sessionID: sessionID,
            startedAt: startedAt,
            lastHeartbeatAt: now,
            expiresAt: now.addingTimeInterval(ttlSeconds)
        )
    }

    public func dictionary() -> [String: Any] {
        [
            "provider": provider,
            "sessionID": sessionID,
            "startedAt": startedAt.timeIntervalSince1970,
            "lastHeartbeatAt": lastHeartbeatAt.timeIntervalSince1970,
            "expiresAt": expiresAt.timeIntervalSince1970
        ]
    }
}
