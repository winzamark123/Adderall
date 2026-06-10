import AdderailShared
import Foundation

struct LeaseManager: Sendable {
    private var leasesByKey: [LeaseKey: Lease]

    init(leases: [Lease] = []) {
        var leasesByKey: [LeaseKey: Lease] = [:]

        for lease in leases {
            leasesByKey[lease.key] = lease
        }

        self.leasesByKey = leasesByKey
    }

    var leases: [Lease] {
        leasesByKey.values.sorted { first, second in
            if first.provider == second.provider {
                return first.sessionID < second.sessionID
            }

            return first.provider < second.provider
        }
    }

    @discardableResult
    mutating func begin(_ command: LeaseCommand, now: Date = Date()) -> Lease {
        let key = LeaseKey(provider: command.provider, sessionID: command.sessionID)

        if let existingLease = leasesByKey[key] {
            let refreshedLease = existingLease.refreshed(at: now, ttlSeconds: command.ttlSeconds)
            leasesByKey[key] = refreshedLease
            return refreshedLease
        }

        let lease = Lease(
            provider: command.provider,
            sessionID: command.sessionID,
            startedAt: now,
            lastHeartbeatAt: now,
            expiresAt: now.addingTimeInterval(command.ttlSeconds)
        )
        leasesByKey[key] = lease
        return lease
    }

    @discardableResult
    mutating func heartbeat(_ command: LeaseCommand, now: Date = Date()) -> Lease {
        begin(command, now: now)
    }

    @discardableResult
    mutating func end(provider: String, sessionID: String) -> Lease? {
        leasesByKey.removeValue(forKey: LeaseKey(provider: provider, sessionID: sessionID))
    }

    @discardableResult
    mutating func expireLeases(now: Date = Date()) -> [Lease] {
        let expiredLeases = leasesByKey.values.filter { lease in
            lease.expiresAt <= now
        }

        for lease in expiredLeases {
            leasesByKey.removeValue(forKey: lease.key)
        }

        return expiredLeases.sorted { first, second in
            first.expiresAt < second.expiresAt
        }
    }

    func activeLeases(now: Date = Date()) -> [Lease] {
        leases.filter { lease in
            lease.expiresAt > now
        }
    }

    func nextExpiry(now: Date = Date()) -> Date? {
        activeLeases(now: now).map(\.expiresAt).min()
    }
}
