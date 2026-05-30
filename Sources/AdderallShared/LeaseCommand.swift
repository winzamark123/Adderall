import Foundation

public struct LeaseCommand: Equatable, Sendable {
    public static let defaultTTLSeconds: TimeInterval = 300

    public let provider: String
    public let sessionID: String
    public let ttlSeconds: TimeInterval

    public init(provider: String, sessionID: String, ttlSeconds: TimeInterval = LeaseCommand.defaultTTLSeconds) {
        self.provider = provider
        self.sessionID = sessionID
        self.ttlSeconds = ttlSeconds
    }
}
