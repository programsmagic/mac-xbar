import Foundation
import Combine

@MainActor
final class NetworkStatsStore: ObservableObject {
    static let shared = NetworkStatsStore()

    @Published var intelligence: NetworkModule.NetworkIntelligence?
    @Published var recentSamples: [SpeedSample] = []
    @Published var todaySummary: DailySummary?
    @Published var insights: [Insight] = []
    @Published var publicIP: String?

    private var pollTask: Task<Void, Never>?

    private init() {}

    func startPolling(interval: TimeInterval = 1.0) {
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
        guard let moduleManager = AppDelegate.shared?.moduleManager else { return }

        if let network = moduleManager.findModule(ofType: NetworkModule.self) {
            intelligence = network.currentIntelligence()
            if let ip = intelligence?.publicIP {
                publicIP = ip
            }
        }

        if publicIP == nil {
            fetchPublicIPIfNeeded()
        }

        if let history = moduleManager.findModule(ofType: HistoryModule.self) {
            recentSamples = history.getRecentSamples(count: 60)
            todaySummary = history.getTodaySummary()
        }

        if let ai = moduleManager.findModule(ofType: AIModule.self) {
            insights = ai.getRecentInsights(count: 20)
        }
    }

    private var isFetchingIP = false

    private func fetchPublicIPIfNeeded() {
        guard !isFetchingIP, publicIP == nil else { return }
        isFetchingIP = true
        Task { [weak self] in
            guard let self else { return }
            guard let url = URL(string: "https://api.ipify.org?format=json") else {
                await MainActor.run { self.isFetchingIP = false }
                return
            }
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ip = json["ip"] as? String {
                await MainActor.run { self.publicIP = ip }
            }
            await MainActor.run { self.isFetchingIP = false }
        }
    }
}
