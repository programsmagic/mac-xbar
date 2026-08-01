import XCTest
@testable import Scheduler

final class SchedulerTests: XCTestCase {
    func testSchedulerSingleton() {
        let scheduler1 = Scheduler.shared
        let scheduler2 = Scheduler.shared
        XCTAssertIdentical(scheduler1, scheduler2)
    }

    func testScheduleAndInvalidate() {
        let scheduler = Scheduler.shared
        var fired = false
        scheduler.schedule(moduleID: "test_module", interval: 0.1) {
            fired = true
        }
        XCTAssertTrue(scheduler.isScheduled("test_module"))
        XCTAssertEqual(scheduler.activeCount(), 1)
        scheduler.invalidate(moduleID: "test_module")
        XCTAssertFalse(scheduler.isScheduled("test_module"))
        XCTAssertEqual(scheduler.activeCount(), 0)
    }

    func testInvalidateAll() {
        let scheduler = Scheduler.shared
        scheduler.schedule(moduleID: "module1", interval: 1.0) {}
        scheduler.schedule(moduleID: "module2", interval: 1.0) {}
        XCTAssertEqual(scheduler.activeCount(), 2)
        scheduler.invalidateAll()
        XCTAssertEqual(scheduler.activeCount(), 0)
    }

    func testPauseAndResume() {
        let scheduler = Scheduler.shared
        scheduler.schedule(moduleID: "pause_test", interval: 1.0) {}
        XCTAssertTrue(scheduler.isScheduled("pause_test"))
        scheduler.pause(moduleID: "pause_test")
        scheduler.resume(moduleID: "pause_test")
        scheduler.invalidate(moduleID: "pause_test")
    }
}