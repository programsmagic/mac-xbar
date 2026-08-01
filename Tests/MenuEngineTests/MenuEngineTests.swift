import XCTest
@testable import MenuEngine
@testable import Core

final class MenuEngineTests: XCTestCase {
    func testMenuEngineCreation() {
        let engine = MenuEngine()
        XCTAssertNotNil(engine)
        XCTAssertFalse(engine.isMenuOpen)
        XCTAssertFalse(engine.compactMode)
    }

    func testMenuEngineUpdateItems() {
        let engine = MenuEngine()
        let items = [
            MenuItem(title: "Item 1", order: 0),
            MenuItem(title: "Item 2", order: 1),
        ]
        engine.update(items: items)
        XCTAssertEqual(engine.currentItems.count, 2)
    }

    func testMenuEngineRemoveAllItems() {
        let engine = MenuEngine()
        let items = [MenuItem(title: "Item 1", order: 0)]
        engine.update(items: items)
        XCTAssertEqual(engine.currentItems.count, 1)
        engine.removeAllItems()
        XCTAssertEqual(engine.currentItems.count, 0)
    }

    func testMenuEngineSetTitle() {
        let engine = MenuEngine()
        engine.setTitle("Test")
        XCTAssertEqual(engine.title, "Test")
    }

    func testMenuEngineDiffComputation() {
        let engine = MenuEngine()
        let oldItems = [MenuItem(title: "Old", id: "1", order: 0)]
        let newItems = [MenuItem(title: "New", id: "1", order: 0)]
        let diff = engine.computeDiff(old: oldItems, new: newItems)
        XCTAssertEqual(diff.updated.count, 1)
        XCTAssertEqual(diff.removed.count, 0)
        XCTAssertEqual(diff.added.count, 0)
    }
}