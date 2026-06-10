import AdderailShared
import Foundation

final class ControllerState {
    private let queue = DispatchQueue(label: "com.adderail.controller.state")
    private let snapshotStore: SnapshotStore
    private let awakeAssertionController: AwakeAssertionController
    private var leaseManager: LeaseManager
    private var expiryTimer: DispatchSourceTimer?

    init(snapshotStore: SnapshotStore, awakeAssertionController: AwakeAssertionController) {
        self.snapshotStore = snapshotStore
        self.awakeAssertionController = awakeAssertionController

        do {
            let snapshot = try snapshotStore.load()
            let now = Date()
            let restoredLeases = snapshot?.leases.filter { lease in
                lease.expiresAt > now
            } ?? []
            self.leaseManager = LeaseManager(leases: restoredLeases)
        } catch {
            self.leaseManager = LeaseManager()
        }

        queue.async { [weak self] in
            guard let self else {
                return
            }

            _ = self.reconcilePowerStateAndPersist()
        }
    }

    func begin(_ command: LeaseCommand, reply: @escaping (NSDictionary) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                reply(errorResponse("Controller state is unavailable."))
                return
            }

            self.leaseManager.expireLeases()
            self.leaseManager.begin(command)
            reply(self.reconcilePowerStateAndPersist())
        }
    }

    func heartbeat(_ command: LeaseCommand, reply: @escaping (NSDictionary) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                reply(errorResponse("Controller state is unavailable."))
                return
            }

            self.leaseManager.expireLeases()
            self.leaseManager.heartbeat(command)
            reply(self.reconcilePowerStateAndPersist())
        }
    }

    func end(provider: String, sessionID: String, reply: @escaping (NSDictionary) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                reply(errorResponse("Controller state is unavailable."))
                return
            }

            self.leaseManager.end(provider: provider, sessionID: sessionID)
            self.leaseManager.expireLeases()
            reply(self.reconcilePowerStateAndPersist())
        }
    }

    func status(reply: @escaping (NSDictionary) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                reply(errorResponse("Controller state is unavailable."))
                return
            }

            self.leaseManager.expireLeases()
            reply(self.reconcilePowerStateAndPersist())
        }
    }

    private func reconcilePowerStateAndPersist() -> NSDictionary {
        do {
            let activeLeases = leaseManager.activeLeases()
            try awakeAssertionController.setActive(activeLeases.isEmpty == false)

            let snapshot = ControllerSnapshot(
                generatedAt: Date(),
                leases: activeLeases,
                awakeAssertionActive: awakeAssertionController.isActive
            )
            try snapshotStore.save(snapshot)
            scheduleNextExpiry()

            return successResponse(snapshot)
        } catch {
            try? awakeAssertionController.setActive(false)
            return errorResponse(error.localizedDescription)
        }
    }

    private func scheduleNextExpiry() {
        expiryTimer?.cancel()
        expiryTimer = nil

        guard let expiryDate = leaseManager.nextExpiry() else {
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        let interval = max(0, expiryDate.timeIntervalSinceNow)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }

            self.leaseManager.expireLeases()
            _ = self.reconcilePowerStateAndPersist()
        }
        timer.resume()
        expiryTimer = timer
    }
}
