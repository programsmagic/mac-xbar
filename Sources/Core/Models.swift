import Foundation

public struct MenuItem: Identifiable, Equatable, Codable {
    public let id: MenuItemID
    public let title: String
    public let subtitle: String?
    public let icon: String?
    public let shortcut: String?
    public let badge: String?
    public let color: String?
    public let isSeparator: Bool
    public let isEnabled: Bool
    public let isHidden: Bool
    public let action: MenuItemAction?
    public let submenu: [MenuItem]?
    public let order: Int
    public let metadata: [String: String]

    public init(
        id: MenuItemID = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        shortcut: String? = nil,
        badge: String? = nil,
        color: String? = nil,
        isSeparator: Bool = false,
        isEnabled: Bool = true,
        isHidden: Bool = false,
        action: MenuItemAction? = nil,
        submenu: [MenuItem]? = nil,
        order: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.shortcut = shortcut
        self.badge = badge
        self.color = color
        self.isSeparator = isSeparator
        self.isEnabled = isEnabled
        self.isHidden = isHidden
        self.action = action
        self.submenu = submenu
        self.order = order
        self.metadata = metadata
    }
}

public enum MenuItemAction: Codable, Equatable {
    case url(String)
    case shell(String)
    case refresh
    case toggle(String)
    case custom(String)
    case none
}

public struct ModuleOutput {
    public let items: [MenuItem]
    public let timestamp: Timestamp
    public let source: ModuleID
    public let error: Error?

    public init(
        items: [MenuItem] = [],
        timestamp: Timestamp = Date(),
        source: ModuleID,
        error: Error? = nil
    ) {
        self.items = items
        self.timestamp = timestamp
        self.source = source
        self.error = error
    }
}

public struct ModuleConfig: Codable, Identifiable {
    public let id: ModuleID
    public let name: String
    public var enabled: Bool
    public let refreshInterval: TimeInterval
    public let order: Int
    public let settings: [String: String]

    public init(
        id: ModuleID,
        name: String,
        enabled: Bool = true,
        refreshInterval: TimeInterval = 60.0,
        order: Int = 0,
        settings: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.refreshInterval = refreshInterval
        self.order = order
        self.settings = settings
    }
}

public struct AppPreferences: Codable {
    public var theme: Theme
    public var density: Density
    public var compactMode: Bool
    public var showArrows: Bool
    public var showUnits: Bool
    public var fixedWidth: Bool
    public var showDisabledModules: Bool
    public var updateInterval: TimeInterval
    public var launchAtLogin: Bool
    public var analyticsEnabled: Bool
    public var moduleConfigs: [ModuleConfig]

    public init(
        theme: Theme = .system,
        density: Density = .compact,
        compactMode: Bool = false,
        showArrows: Bool = true,
        showUnits: Bool = true,
        fixedWidth: Bool = false,
        showDisabledModules: Bool = false,
        updateInterval: TimeInterval = 1.0,
        launchAtLogin: Bool = false,
        analyticsEnabled: Bool = false,
        moduleConfigs: [ModuleConfig] = []
    ) {
        self.theme = theme
        self.density = density
        self.compactMode = compactMode
        self.showArrows = showArrows
        self.showUnits = showUnits
        self.fixedWidth = fixedWidth
        self.showDisabledModules = showDisabledModules
        self.updateInterval = updateInterval
        self.launchAtLogin = launchAtLogin
        self.analyticsEnabled = analyticsEnabled
        self.moduleConfigs = moduleConfigs
    }
}

public struct NetworkDisplayStats {
    public var downloadSpeed: String
    public var uploadSpeed: String
    public var latency: String
    public var interface: String
    public var isConnected: Bool
    public var publicIP: String
    public var sessionDownloaded: String
    public var sessionUploaded: String

    public init(
        downloadSpeed: String = "\u{2014}",
        uploadSpeed: String = "\u{2014}",
        latency: String = "\u{2014}",
        interface: String = "\u{2014}",
        isConnected: Bool = false,
        publicIP: String = "\u{2014}",
        sessionDownloaded: String = "0 B",
        sessionUploaded: String = "0 B"
    ) {
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.latency = latency
        self.interface = interface
        self.isConnected = isConnected
        self.publicIP = publicIP
        self.sessionDownloaded = sessionDownloaded
        self.sessionUploaded = sessionUploaded
    }
}