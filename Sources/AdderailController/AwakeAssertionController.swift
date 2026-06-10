import Foundation
import IOKit.pwr_mgt

final class AwakeAssertionController {
    private var assertionID = IOPMAssertionID(0)

    var isActive: Bool {
        assertionID != 0
    }

    func setActive(_ shouldBeActive: Bool) throws {
        if shouldBeActive {
            try activate()
        } else {
            deactivate()
        }
    }

    private func activate() throws {
        if isActive {
            return
        }

        var newAssertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithDescription(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            "Adderail" as CFString,
            "Active agent lease" as CFString,
            "Adderail is keeping the Mac awake while an agent lease is active." as CFString,
            nil,
            0,
            nil,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            throw AwakeAssertionError.createFailed(result)
        }

        assertionID = newAssertionID
    }

    private func deactivate() {
        if isActive == false {
            return
        }

        IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(0)
    }

    deinit {
        deactivate()
    }
}

enum AwakeAssertionError: LocalizedError {
    case createFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .createFailed(let code):
            return "Could not create IOPMAssertion. IOKit returned \(code)."
        }
    }
}
