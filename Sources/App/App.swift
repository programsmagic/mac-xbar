import AppKit
import SwiftUI

@main
struct mac_xbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        SettingsWindow()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, SchedulerDelegate {
    var menuEngine: MenuEngine?
    var scheduler: Scheduler?
    var moduleManager: ModuleManager?
    private var networkModule: NetworkModule?
    private var adaptiveMode: MenuBarMode = .normal
    private var lastSpeedUpdate: Date = Date()
    private var mainRefreshAction: (() -> Void)?
    private var preferencesObserver: AnyObject?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.info("mac-xbar launching")

        PerformanceModule.shared.recordStartup()

        menuEngine = MenuEngine()
        menuEngine?.delegate = self

        scheduler = Scheduler()
        scheduler?.delegate = self

        moduleManager = ModuleManager()
        AppDelegate.shared = self

        preferencesObserver = NotificationCenter.default.addObserver(
            forName: .preferencesChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyPreferences()
        }

        Task {
            await startModules()
        }

        setupStatusItem()
        startUpdateChecker()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.info("mac-xbar terminating")
        scheduler?.invalidateAll()
        moduleManager?.invalidateAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Scheduler Delegate

    nonisolated func scheduler(_ scheduler: Scheduler, didFireForModule moduleID: String) {
        Task { @MainActor in
            await refreshSingleModule(moduleID)
        }
    }

    nonisolated func schedulerDidTick(_ scheduler: Scheduler) {
        Task { @MainActor in
            await refreshAndDisplay()
        }
    }

    // MARK: - Setup

    private func setupStatusItem() {
        applyPreferences()
        menuEngine?.setIcon(NSImage(systemSymbolName: "network", accessibilityDescription: nil))
        menuEngine?.setTitle("\u{2014}")
        menuEngine?.setTooltip("mac-xbar — Network Speed Monitor")
    }

    private func applyPreferences() {
        let prefs = PreferencesManager.shared.preferences
        menuEngine?.theme = prefs.theme
        menuEngine?.density = prefs.density
        menuEngine?.fixedWidth = prefs.fixedWidth
        menuEngine?.showArrows = prefs.showArrows
        menuEngine?.compactMode = prefs.compactMode
        if scheduler?.isScheduled("__main__") == true,
           scheduler?.scheduledModuleIDs().contains("__main__") == true {
            scheduleMainRefresh()
        }
    }

    private func startUpdateChecker() {
        UpdateChecker.shared.startPeriodicChecks(interval: 3600 * 6)
    }

    private func startModules() async {
        guard let manager = moduleManager else { return }
        registerBuiltInModules(manager: manager)

        for module in manager.registeredModules {
            guard module.config.enabled else { continue }
            do {
                try await module.initialize()
                if let net = module as? NetworkModule {
                    networkModule = net
                    net.speedObserver = self
                }
            } catch {
                Logger.shared.error("Failed to initialize module \(module.id): \(error.localizedDescription)")
            }
        }

        mainRefreshAction = { [weak self] in
            Task { @MainActor in
                await self?.refreshAndDisplay()
            }
        }
        scheduleMainRefresh()
    }

    private func registerBuiltInModules(manager: ModuleManager) {
        manager.register(NetworkModule())
        manager.register(SystemModule())
        manager.register(DeveloperModule())
        manager.register(ProductivityModule())
        manager.register(HistoryModule())
        manager.register(AIModule())
        manager.register(QuickActionsModule())

        if PreferencesManager.shared.preferences.moduleConfigs.isEmpty {
            let configs = manager.registeredModules.map {
                ModuleConfig(
                    id: $0.id,
                    name: $0.name,
                    enabled: $0.config.enabled,
                    refreshInterval: $0.config.refreshInterval,
                    order: $0.config.order,
                    settings: $0.config.settings
                )
            }
            PreferencesManager.shared.update { prefs in
                prefs.moduleConfigs = configs
            }
        }
        Logger.shared.info("All built-in modules registered")
    }

    private func scheduleMainRefresh() {
        guard let scheduler, let mainRefreshAction else { return }
        scheduler.schedule(
            moduleID: "__main__",
            interval: PreferencesManager.shared.preferences.updateInterval,
            leewayMs: 100,
            action: mainRefreshAction
        )
    }

    // MARK: - Refresh

    private func refreshAndDisplay(force: Bool = false) async {
        guard let manager = moduleManager else { return }
        let allItems = await manager.refreshAll(force: force)
        menuEngine?.update(items: allItems)
    }

    private func refreshSingleModule(_ moduleID: String) async {
        guard let manager = moduleManager,
            let module = manager.module(withID: moduleID),
            module.config.enabled else { return }
        do {
            _ = try await module.refresh()
            await refreshAndDisplay()
        } catch {
            Logger.shared.error("Failed to refresh \(moduleID): \(error.localizedDescription)")
        }
    }
}

// MARK: - MenuEngineDelegate

@MainActor
extension AppDelegate: MenuEngineDelegate {
    func menuEngine(_ engine: MenuEngine, didSelectItem item: MenuItem) {
        guard let action = item.action else { return }
        handleAction(action)
    }

    func menuEngineDidRequestDashboard(_ engine: MenuEngine) {
        guard let button = engine.statusButton else { return }
        DashboardPanel.shared.toggle(from: button)
    }

    func menuEngineWillOpen(_ engine: MenuEngine) {
        Task {
            await refreshAndDisplay(force: true)
        }
    }

    func menuEngineDidClose(_ engine: MenuEngine) {}

    private func handleAction(_ action: MenuItemAction) {
        switch action {
        case .url(let urlString):
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        case .shell(let command):
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = ["-c", command]
            try? task.run()
        case .refresh:
            Task { await refreshAndDisplay() }
        case .toggle(let moduleID):
            moduleManager?.toggleModule(moduleID, scheduler: scheduler)
        case .custom(let identifier):
            handleQuickAction(identifier)
        case .none:
            break
        }
    }

    private func handleQuickAction(_ identifier: String) {
        guard let quickActions = moduleManager?.findModule(ofType: QuickActionsModule.self) else {
            Logger.shared.error("QuickActionsModule not found")
            return
        }
        guard let action = QuickAction(rawValue: identifier) else {
            Logger.shared.error("Unknown quick action: \(identifier)")
            return
        }
        Task {
            await quickActions.executeAction(action)
            await refreshAndDisplay()
        }
    }
}

// MARK: - NetworkSpeedObserver

extension AppDelegate: NetworkSpeedObserver {
    nonisolated func networkModule(_ module: NetworkModule, didUpdateSpeed download: Double, upload: Double, downloadFormatted: String, uploadFormatted: String) {
        let dlShort = AppDelegate.formatBarSpeed(download)
        let ulShort = AppDelegate.formatBarSpeed(upload)

        let intel = module.currentIntelligence()
        let latency: Double = intel.latency
        let interface: String = intel.interfaceType

        Task { @MainActor in
            let showUnits = PreferencesManager.shared.preferences.showUnits
            let dlShortFinal = showUnits
                ? AppDelegate.barSpeed(download, showUnits: true)
                : dlShort
            let ulShortFinal = showUnits
                ? AppDelegate.barSpeed(upload, showUnits: true)
                : ulShort
            if let history = AppDelegate.shared?.moduleManager?.findModule(ofType: HistoryModule.self) {
                history.recordSample(download: download, upload: upload, latency: latency, interface: interface)
            }

            if let ai = AppDelegate.shared?.moduleManager?.findModule(ofType: AIModule.self) {
                ai.analyzeSpeed(download: download, upload: upload, latency: latency, rssi: intel.wifiRSSI)
            }

            let mode = self.updateAdaptiveMode(download: download, upload: upload)
            let title = self.formatTitleForMode(mode, dl: dlShortFinal, ul: ulShortFinal, dlFull: downloadFormatted, ulFull: uploadFormatted)
            let tip = "Download: \(downloadFormatted)\nUpload: \(uploadFormatted)\nMode: \(mode.displayName)"

            self.menuEngine?.setTitle(title)
            self.menuEngine?.setTooltip(tip)

            PreferencesManager.shared.updateNetworkStats(
                downloadSpeed: downloadFormatted,
                uploadSpeed: uploadFormatted,
                latency: formatLatency(intel.latency),
                interface: intel.interfaceType,
                isConnected: intel.isConnected,
                publicIP: intel.publicIP
            )
            self.lastSpeedUpdate = Date()
        }
    }

    private func formatLatency(_ latency: Double) -> String {
        latency >= 0 ? String(format: "%.0f ms", latency) : "—"
    }

    nonisolated func networkModule(_ module: NetworkModule, didUpdateIntelligence intelligence: NetworkModule.NetworkIntelligence) {
        Task { @MainActor in
            PreferencesManager.shared.updateNetworkStats(
                downloadSpeed: module.formatSpeedShort(intelligence.download),
                uploadSpeed: module.formatSpeedShort(intelligence.upload),
                latency: formatLatency(intelligence.latency),
                interface: intelligence.interfaceType,
                isConnected: intelligence.isConnected,
                publicIP: intelligence.publicIP
            )
        }
    }

    private func updateAdaptiveMode(download: Double, upload: Double) -> MenuBarMode {
        let totalSpeed = download + upload

        if totalSpeed < 100 {
            if Date().timeIntervalSince(lastSpeedUpdate) > 30 {
                return .idle
            }
            return adaptiveMode
        } else if totalSpeed < 1024 * 1024 {
            return .light
        } else if totalSpeed > 10 * 1024 * 1024 {
            return .streaming
        } else {
            return .normal
        }
    }

    private func formatTitleForMode(_ mode: MenuBarMode, dl: String, ul: String, dlFull: String, ulFull: String) -> String {
        let prefs = PreferencesManager.shared.preferences
        let showArrows = prefs.showArrows
        let compact = prefs.compactMode

        let dlPart = showArrows ? "\u{2193}\u{00A0}\(dl)" : "\(dl)"
        let ulPart = showArrows ? "\u{2191}\u{00A0}\(ul)" : "\(ul)"

        switch mode {
        case .idle:
            return ""
        case .light:
            return compact ? dlPart : "\(dlPart) \(ulPart)"
        case .normal:
            return compact ? "\(dlPart) \(ulPart)" : "\(dlPart)  \(ulPart)"
        case .developer:
            return "\u{21BB} \(dlPart) \(ulPart)"
        case .streaming:
            return "▶ \u{2193}\(dl) \u{2191}\(ul)"
        }
    }

    static func barSpeed(_ bytesPerSecond: Double, showUnits: Bool) -> String {
        showUnits ? formatSpeedBytes(bytesPerSecond) : formatBarSpeed(bytesPerSecond)
    }

    private static func formatSpeedBytes(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1 { return "\u{2014}" }
        if bytesPerSecond < 1024 { return String(format: "%.0f B/s", bytesPerSecond) }
        if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        }
        if bytesPerSecond < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        }
        return String(format: "%.2f GB/s", bytesPerSecond / (1024 * 1024 * 1024))
    }

    nonisolated static func formatBarSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1 { return "\u{2014}" }
        if bytesPerSecond < 1024 { return String(format: "%4.0fB", bytesPerSecond) }
        if bytesPerSecond < 1024 * 1024 {
            let v = bytesPerSecond / 1024
            return v < 10 ? String(format: "%5.1fK", v) : String(format: "%4.0fK", v)
        }
        if bytesPerSecond < 1024 * 1024 * 1024 {
            let v = bytesPerSecond / (1024 * 1024)
            return v < 10 ? String(format: "%5.1fM", v) : String(format: "%4.0fM", v)
        }
        let v = bytesPerSecond / (1024 * 1024 * 1024)
        return String(format: "%4.1fG", v)
    }
}

// MARK: - Adaptive Mode

enum MenuBarMode: String, CaseIterable {
    case idle, light, normal, developer, streaming

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .light: return "Light"
        case .normal: return "Normal"
        case .developer: return "Developer"
        case .streaming: return "Streaming"
        }
    }

    var icon: String {
        switch self {
        case .idle: return "moon.fill"
        case .light: return "leaf.fill"
        case .normal: return "gauge.with.dots.needle.33percent"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .streaming: return "play.fill"
        }
    }
}

// MARK: - AppDelegate Access for Settings

extension AppDelegate {
    static var shared: AppDelegate?

    var theScheduler: Scheduler? { scheduler }
}

// MARK: - Settings Window

struct SettingsWindow: Scene {
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
