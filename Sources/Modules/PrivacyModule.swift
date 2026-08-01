import Foundation

public final class PrivacyModule {
    public static let shared = PrivacyModule()

    public struct PrivacySettings: Codable {
        public var telemetryEnabled: Bool
        public var localStorageOnly: Bool
        public var permissionTransparency: Bool
        public var encryptedSecrets: Bool
        public var openArchitecture: Bool

        public init(
            telemetryEnabled: Bool = false,
            localStorageOnly: Bool = true,
            permissionTransparency: Bool = true,
            encryptedSecrets: Bool = true,
            openArchitecture: Bool = true
        ) {
            self.telemetryEnabled = telemetryEnabled
            self.localStorageOnly = localStorageOnly
            self.permissionTransparency = permissionTransparency
            self.encryptedSecrets = encryptedSecrets
            self.openArchitecture = openArchitecture
        }
    }

    private var settings: PrivacySettings {
        get {
            (try? Storage.shared.load(PrivacySettings.self, forKey: "privacy")) ?? PrivacySettings()
        }
        set {
            try? Storage.shared.save(newValue, forKey: "privacy")
        }
    }

    public var isTelemetryEnabled: Bool {
        get { settings.telemetryEnabled }
        set { settings.telemetryEnabled = newValue }
    }

    public var isLocalStorageOnly: Bool {
        get { settings.localStorageOnly }
        set { settings.localStorageOnly = newValue }
    }

    public var isPermissionTransparencyEnabled: Bool {
        get { settings.permissionTransparency }
        set { settings.permissionTransparency = newValue }
    }

    public var isEncryptedSecretsEnabled: Bool {
        get { settings.encryptedSecrets }
        set { settings.encryptedSecrets = newValue }
    }

    public var isOpenArchitectureEnabled: Bool {
        get { settings.openArchitecture }
        set { settings.openArchitecture = newValue }
    }

    public func encrypt(_ value: String) -> String {
        guard isEncryptedSecretsEnabled else { return value }
        return value.base64EncodedString()
    }

    public func decrypt(_ value: String) -> String? {
        guard isEncryptedSecretsEnabled else { return value }
        return Data(base64Encoded: value)?.string(encoding: .utf8)
    }

    public func logPermissionRequest(_ permission: String, module: String) {
        guard isPermissionTransparency else { return }
        Logger.shared.info("Permission request: \(permission) from module \(module)")
    }

    public func clearAllData() {
        try? Storage.shared.clear()
    }
}