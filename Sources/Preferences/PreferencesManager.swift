import Foundation
import SwiftUI
import ServiceManagement

public final class PreferencesManager: ObservableObject {
    public static let shared = PreferencesManager()

    private let storage = Storage.shared
    private let preferencesKey = "preferences"

    @Published public var preferences: AppPreferences {
        didSet {
            try? save()
            syncLaunchAtLogin()
        }
    }

    @Published public var networkStats = NetworkDisplayStats()

    private init() {
        self.preferences = (try? storage.load(AppPreferences.self, forKey: preferencesKey)) ?? AppPreferences()
        syncLaunchAtLogin()
    }

    public func update(_ update: (inout AppPreferences) -> Void) {
        var prefs = preferences
        update(&prefs)
        preferences = prefs
    }

    public func updateNetworkStats(
        downloadSpeed: String? = nil,
        uploadSpeed: String? = nil,
        latency: String? = nil,
        interface: String? = nil,
        isConnected: Bool? = nil,
        publicIP: String? = nil,
        sessionDownloaded: String? = nil,
        sessionUploaded: String? = nil
    ) {
        var stats = networkStats
        if let v = downloadSpeed { stats.downloadSpeed = v }
        if let v = uploadSpeed { stats.uploadSpeed = v }
        if let v = latency { stats.latency = v }
        if let v = interface { stats.interface = v }
        if let v = isConnected { stats.isConnected = v }
        if let v = publicIP { stats.publicIP = v }
        if let v = sessionDownloaded { stats.sessionDownloaded = v }
        if let v = sessionUploaded { stats.sessionUploaded = v }
        networkStats = stats
    }

    public func reset() {
        preferences = AppPreferences()
        networkStats = NetworkDisplayStats()
        syncLaunchAtLogin()
    }

    private func syncLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if preferences.launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Logger.shared.error("Failed to update launch at login: \(error.localizedDescription)")
            }
        }
    }

    private func save() throws {
        try storage.save(preferences, forKey: preferencesKey)
    }
}
