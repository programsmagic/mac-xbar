import Foundation

public final class Cache {
    public static let shared = Cache()

    private let cache: NSCache<NSString, CacheEntry>
    private let defaultTTL: TimeInterval

    private init() {
        self.cache = NSCache<NSString, CacheEntry>()
        self.defaultTTL = 300.0
        cache.countLimit = 1000
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }

    public func set<T: Codable>(_ value: T, forKey key: CacheKey, ttl: TimeInterval? = nil) {
        let entry = CacheEntry(value: value, expiry: Date().addingTimeInterval(ttl ?? defaultTTL))
        cache.setObject(entry, forKey: key as NSString, cost: memoryCost(for: value))
    }

    public func get<T: Codable>(_ type: T.Type, forKey key: CacheKey) -> T? {
        guard let entry = cache.object(forKey: key as NSString) else { return nil }
        guard !entry.isExpired else {
            cache.removeObject(forKey: key as NSString)
            return nil
        }
        return entry.value as? T
    }

    public func remove(forKey key: CacheKey) {
        cache.removeObject(forKey: key as NSString)
    }

    public func clear() {
        cache.removeAllObjects()
    }

    public func hasKey(_ key: CacheKey) -> Bool {
        cache.object(forKey: key as NSString) != nil
    }

    public func pruneExpired() {
        // NSCache doesn't support key enumeration; skip pruning
    }

    private func memoryCost<T: Codable>(for value: T) -> Int {
        if let data = try? JSONEncoder().encode(value) {
            return data.count
        }
        return 1024
    }
}

private final class CacheEntry: NSObject, Codable {
    let value: Any
    let expiry: Date

    init(value: Any, expiry: Date) {
        self.value = value
        self.expiry = expiry
    }

    var isExpired: Bool {
        Date() > expiry
    }

    enum CodingKeys: String, CodingKey {
        case expiry
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(expiry, forKey: .expiry)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        expiry = try container.decode(Date.self, forKey: .expiry)
        value = ()
    }
}