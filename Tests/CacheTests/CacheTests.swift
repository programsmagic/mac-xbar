import XCTest
@testable import Cache

final class CacheTests: XCTestCase {
    func testCacheSingleton() {
        let cache1 = Cache.shared
        let cache2 = Cache.shared
        XCTAssertIdentical(cache1, cache2)
    }

    func testSetAndGet() {
        let cache = Cache.shared
        cache.set("hello", forKey: "test_key", ttl: 60.0)
        let value: String? = cache.get(String.self, forKey: "test_key")
        XCTAssertEqual(value, "hello")
        cache.remove(forKey: "test_key")
    }

    func testCacheMiss() {
        let cache = Cache.shared
        let value: String? = cache.get(String.self, forKey: "nonexistent")
        XCTAssertNil(value)
    }

    func testTTLExpiry() throws {
        let cache = Cache.shared
        cache.set("expired", forKey: "expiring_key", ttl: 0.01)
        let value: String? = cache.get(String.self, forKey: "expiring_key")
        XCTAssertEqual(value, "expired")
        try Task.sleep(nanoseconds: 50_000_000)
        cache.pruneExpired()
        let expiredValue: String? = cache.get(String.self, forKey: "expiring_key")
        XCTAssertNil(expiredValue)
    }

    func testClear() {
        let cache = Cache.shared
        cache.set("value1", forKey: "key1")
        cache.set("value2", forKey: "key2")
        cache.clear()
        let v1: String? = cache.get(String.self, forKey: "key1")
        let v2: String? = cache.get(String.self, forKey: "key2")
        XCTAssertNil(v1)
        XCTAssertNil(v2)
    }

    func testHasKey() {
        let cache = Cache.shared
        cache.set("value", forKey: "haskey_test")
        XCTAssertTrue(cache.hasKey("haskey_test"))
        XCTAssertFalse(cache.hasKey("nonexistent"))
        cache.remove(forKey: "haskey_test")
    }
}