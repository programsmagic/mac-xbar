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