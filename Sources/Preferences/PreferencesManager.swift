import Foundation

public final class PreferencesManager {
    public static let shared = PreferencesManager()

    private let storage = Storage.shared
    private let preferencesKey = "preferences"

    public private(set) var preferences: AppPreferences {
        didSet {
            try? save()
        }
    }

    private init() {
        self.preferences = (try? storage.load(AppPreferences.self, forKey: preferencesKey)) ?? AppPreferences()
    }

    public func update(_ update: (inout AppPreferences) -> Void) {
        var prefs = preferences
        update(&prefs)
        preferences = prefs
    }

    public func reset() {
        preferences = AppPreferences()
    }

    private func save() throws {
        try storage.save(preferences, forKey: preferencesKey)
    }
}