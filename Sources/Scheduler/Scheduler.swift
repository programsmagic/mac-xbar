import Foundation
import os.log

public protocol SchedulerDelegate: AnyObject {
    func scheduler(_ scheduler: Scheduler, didFireForModule moduleID: String)
    func schedulerDidTick(_ scheduler: Scheduler)
}

public final class Scheduler {
    public static let shared = Scheduler()

    public weak var delegate: SchedulerDelegate?

    private var timers: [String: DispatchSourceTimer] = [:]
    private let queue = DispatchQueue(label: "com.macxbar.scheduler", qos: .utility)
    private let log = OSLog(subsystem: "com.macxbar.app", category: "scheduler")

    public static let defaultLeewayMs: UInt64 = 500

    public init() {}

    deinit {
        invalidateAll()
    }

    public func schedule(
        moduleID: String,
        interval: TimeInterval,
        leewayMs: UInt64 = Scheduler.defaultLeewayMs,
        action: @escaping () -> Void
    ) {
        invalidate(moduleID: moduleID)

        guard interval > 0 else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now(),
            repeating: .seconds(Int(interval)),
            leeway: .milliseconds(Int(leewayMs))
        )
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            os_log("Timer fired for %{public}@", log: self.log, type: .debug, moduleID)
            self.delegate?.scheduler(self, didFireForModule: moduleID)
            action()
        }
        timer.resume()
        timers[moduleID] = timer

        os_log("Scheduled %{public}@ with interval %{public}f, leeway %{public}dms", log: log, type: .info, moduleID, interval, leewayMs)
    }

    public func reschedule(moduleID: String, interval: TimeInterval, action: @escaping () -> Void) {
        guard timers[moduleID] != nil else { return }
        schedule(moduleID: moduleID, interval: interval, action: action)
    }

    public func invalidate(moduleID: String) {
        timers[moduleID]?.cancel()
        timers.removeValue(forKey: moduleID)
    }

    public func invalidateAll() {
        for (_, timer) in timers {
            timer.cancel()
        }
        timers.removeAll()
    }

    public func pause(moduleID: String) {
        timers[moduleID]?.suspend()
    }

    public func resume(moduleID: String) {
        timers[moduleID]?.resume()
    }

    public func isScheduled(_ moduleID: String) -> Bool {
        timers[moduleID] != nil
    }

    public func activeCount() -> Int {
        timers.count
    }

    public func scheduledModuleIDs() -> [String] {
        Array(timers.keys)
    }
}