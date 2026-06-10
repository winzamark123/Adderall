import Foundation

public struct ControllerSnapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let leases: [Lease]
    public let awakeAssertionActive: Bool

    public init(generatedAt: Date, leases: [Lease], awakeAssertionActive: Bool) {
        self.generatedAt = generatedAt
        self.leases = leases
        self.awakeAssertionActive = awakeAssertionActive
    }

    public func dictionary() -> [String: Any] {
        [
            "generatedAt": generatedAt.timeIntervalSince1970,
            "awakeAssertionActive": awakeAssertionActive,
            "activeLeases": leases.map { lease in
                lease.dictionary()
            }
        ]
    }
}
