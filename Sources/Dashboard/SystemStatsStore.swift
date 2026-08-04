import Foundation
import Combine

@MainActor
final class SystemStatsStore: ObservableObject {
    static let shared = SystemStatsStore()

    @Published var metrics: SystemMetrics?
    @Published var lastUpdated: Date?

    private var pollTask: Task<Void, Never>?

    private init() {}

    func startPolling(interval: TimeInterval = 2.0) {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func pollOnce() async {
        await poll()
    }

    private func poll() async {
        let result = await Task.detached(priority: .utility) {
            SystemInfoCollector.shared.collectAll()
        }.value
        metrics = result
        lastUpdated = Date()
    }
}
