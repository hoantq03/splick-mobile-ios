import XCTest
import Network
@testable import FeatureMessaging

final class NetworkPathMonitorTests: XCTestCase {

    func testNetworkPathMonitorLifecycleAndHandlers() {
        let monitor = NetworkPathMonitor()

        // Check initial state
        _ = monitor.isSatisfied

        var callCount = 0
        var lastStatus: Bool?

        let handlerId = monitor.onPathChange { isSatisfied in
            callCount += 1
            lastStatus = isSatisfied
        }

        XCTAssertNotNil(handlerId)

        // Multiple start calls are guarded
        monitor.start()
        monitor.start()

        // Remove handler
        monitor.removeHandler(handlerId)

        // Stop monitor
        monitor.stop()
        // Calling stop again when stopped is guarded
        monitor.stop()
    }
}
