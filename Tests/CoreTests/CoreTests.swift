import XCTest
@testable import Core

final class CoreTests: XCTestCase {
    func testMenuItemCreation() {
        let item = MenuItem(title: "Test", order: 0)
        XCTAssertEqual(item.title, "Test")
        XCTAssertEqual(item.order, 0)
        XCTAssertFalse(item.isSeparator)
        XCTAssertTrue(item.isEnabled)
    }

    func testMenuItemEquality() {
        let item1 = MenuItem(id: "1", title: "Test", order: 0)
        let item2 = MenuItem(id: "1", title: "Test", order: 0)
        let item3 = MenuItem(id: "2", title: "Test", order: 0)
        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
    }

    func testAppPreferencesDefaultValues() {
        let prefs = AppPreferences()
        XCTAssertEqual(prefs.theme, .system)
        XCTAssertFalse(prefs.compactMode)
        XCTAssertEqual(prefs.updateInterval, 60.0)
        XCTAssertFalse(prefs.analyticsEnabled)
    }

    func testStorageSaveAndLoad() throws {
        let storage = Storage.shared
        let prefs = AppPreferences(theme: .dark, compactMode: true)
        try storage.save(prefs, forKey: "test_prefs")
        let loaded = try storage.load(AppPreferences.self, forKey: "test_prefs")
        XCTAssertEqual(loaded?.theme, .dark)
        XCTAssertEqual(loaded?.compactMode, true)
        try storage.remove(forKey: "test_prefs")
    }

    func testLoggerLevels() {
        let logger = Logger(minimumLevel: .debug)
        logger.debug("Debug message")
        logger.info("Info message")
        logger.warning("Warning message")
        logger.error("Error message")
        XCTAssertTrue(true)
    }

    func testDiagnosticsRecording() {
        Diagnostics.shared.record(name: "test_metric", value: 42.0, unit: "ms")
        let snapshot = Diagnostics.shared.snapshot(name: "test_metric")
        XCTAssertEqual(snapshot?.value, 42.0)
        XCTAssertEqual(snapshot?.unit, "ms")
    }
}