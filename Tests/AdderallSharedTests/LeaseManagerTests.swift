import XCTest
@testable import AdderallShared

final class LeaseManagerTests: XCTestCase {
    func testBeginCreatesLease() {
        var manager = LeaseManager()
        let now = Date(timeIntervalSince1970: 100)

        let lease = manager.begin(LeaseCommand(provider: "claude", sessionID: "abc", ttlSeconds: 30), now: now)

        XCTAssertEqual(lease.provider, "claude")
        XCTAssertEqual(lease.sessionID, "abc")
        XCTAssertEqual(lease.startedAt, now)
        XCTAssertEqual(lease.lastHeartbeatAt, now)
        XCTAssertEqual(lease.expiresAt, Date(timeIntervalSince1970: 130))
        XCTAssertEqual(manager.activeLeases(now: now).count, 1)
    }

    func testRepeatedBeginRefreshesExistingLeaseWithoutChangingStartTime() {
        var manager = LeaseManager()
        let firstDate = Date(timeIntervalSince1970: 100)
        let secondDate = Date(timeIntervalSince1970: 120)

        manager.begin(LeaseCommand(provider: "claude", sessionID: "abc", ttlSeconds: 30), now: firstDate)
        let lease = manager.begin(LeaseCommand(provider: "claude", sessionID: "abc", ttlSeconds: 60), now: secondDate)

        XCTAssertEqual(lease.startedAt, firstDate)
        XCTAssertEqual(lease.lastHeartbeatAt, secondDate)
        XCTAssertEqual(lease.expiresAt, Date(timeIntervalSince1970: 180))
        XCTAssertEqual(manager.leases.count, 1)
    }

    func testHeartbeatCreatesLeaseWhenMissing() {
        var manager = LeaseManager()
        let now = Date(timeIntervalSince1970: 100)

        let lease = manager.heartbeat(LeaseCommand(provider: "claude", sessionID: "abc", ttlSeconds: 30), now: now)

        XCTAssertEqual(lease.startedAt, now)
        XCTAssertEqual(manager.leases.count, 1)
    }

    func testEndRemovesLease() {
        var manager = LeaseManager()
        manager.begin(LeaseCommand(provider: "claude", sessionID: "abc", ttlSeconds: 30), now: Date(timeIntervalSince1970: 100))

        let removedLease = manager.end(provider: "claude", sessionID: "abc")

        XCTAssertNotNil(removedLease)
        XCTAssertTrue(manager.leases.isEmpty)
    }

    func testExpireLeasesRemovesOnlyExpiredLeases() {
        var manager = LeaseManager()
        manager.begin(LeaseCommand(provider: "claude", sessionID: "expired", ttlSeconds: 30), now: Date(timeIntervalSince1970: 100))
        manager.begin(LeaseCommand(provider: "claude", sessionID: "active", ttlSeconds: 60), now: Date(timeIntervalSince1970: 100))

        let expiredLeases = manager.expireLeases(now: Date(timeIntervalSince1970: 140))

        XCTAssertEqual(expiredLeases.map(\.sessionID), ["expired"])
        XCTAssertEqual(manager.leases.map(\.sessionID), ["active"])
    }

    func testNextExpiryIgnoresExpiredLeases() {
        var manager = LeaseManager()
        manager.begin(LeaseCommand(provider: "claude", sessionID: "expired", ttlSeconds: 30), now: Date(timeIntervalSince1970: 100))
        manager.begin(LeaseCommand(provider: "claude", sessionID: "active", ttlSeconds: 60), now: Date(timeIntervalSince1970: 100))

        let nextExpiry = manager.nextExpiry(now: Date(timeIntervalSince1970: 140))

        XCTAssertEqual(nextExpiry, Date(timeIntervalSince1970: 160))
    }
}
