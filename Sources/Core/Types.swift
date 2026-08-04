import Foundation

public typealias ModuleID = String
public typealias MenuItemID = String
public typealias CacheKey = String
public typealias Timestamp = Date

public enum AppEnvironment {
    case development
    case staging
    case production
}

public enum Theme: String, Codable, CaseIterable {
    case system
    case light
    case dark
}

public enum Density: String, Codable, CaseIterable {
    case compact
    case normal
    case comfortable
}

public enum MenuBarLayout: String, Codable, CaseIterable {
    case minimal
    case native
    case professional
    case graph
    case badge
    case adaptive

    public var title: String {
        switch self {
        case .minimal: return "Minimal"
        case .native: return "Native"
        case .professional: return "Professional"
        case .graph: return "Graph"
        case .badge: return "Badge"
        case .adaptive: return "Adaptive"
        }
    }

    public var example: String {
        switch self {
        case .minimal: return "⇣7.3 ⇡1.7"
        case .native: return "🌐 7.3↓ 1.7↑"
        case .professional: return "Wi‑Fi ⇣7.3 ⇡1.7 24ms"
        case .graph: return "▁▂▃▅ ⇣7.3"
        case .badge: return "[D 7.3] [U 1.7]"
        case .adaptive: return "Auto — switches on traffic"
        }
    }
}

public enum TrafficStyle: String, Codable, CaseIterable {
    case monochrome
    case accent
    case colored
    case adaptive
    case highContrast

    public var title: String {
        switch self {
        case .monochrome: return "Monochrome"
        case .accent: return "Accent Color"
        case .colored: return "Download/Upload Colors"
        case .adaptive: return "Adaptive"
        case .highContrast: return "High Contrast"
        }
    }
}

public enum BadgeStyle: String, Codable, CaseIterable {
    case off
    case subtle
    case filled

    public var title: String {
        switch self {
        case .off: return "Off"
        case .subtle: return "Subtle Capsule"
        case .filled: return "Filled Capsule"
        }
    }
}

public enum MenuBarIcon: String, Codable, CaseIterable {
    case network
    case wifi
    case speedometer
    case gauge
    case arrows
    case bolt
    case globe
    case radar
    case none

    public var title: String {
        switch self {
        case .network: return "Network"
        case .wifi: return "Wi-Fi"
        case .speedometer: return "Speedometer"
        case .gauge: return "Gauge"
        case .arrows: return "Up/Down Arrows"
        case .bolt: return "Bolt"
        case .globe: return "Globe"
        case .radar: return "Radar"
        case .none: return "None"
        }
    }

    public var symbol: String? {
        switch self {
        case .network: return "network"
        case .wifi: return "wifi"
        case .speedometer: return "speedometer"
        case .gauge: return "gauge.with.dots.needle.33percent"
        case .arrows: return "arrow.up.arrow.down"
        case .bolt: return "bolt.fill"
        case .globe: return "globe"
        case .radar: return "antenna.radiowaves.left.and.right"
        case .none: return nil
        }
    }
}

public enum ModuleState: Codable {
    case active
    case paused
    case suspended
    case error(String)
}

public struct ModuleInfo: Codable {
    public let id: ModuleID
    public let name: String
    public let version: String
    public let category: String

    public init(
        id: ModuleID,
        name: String,
        version: String,
        category: String
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.category = category
    }
}