import XCTest
@testable import Renderer
@testable import Core

final class RendererTests: XCTestCase {
    func testRendererCreation() {
        let renderer = Renderer()
        XCTAssertNotNil(renderer)
    }

    func testDiffWithAddedItems() {
        let renderer = Renderer()
        let oldItems: [MenuItem] = []
        let newItems = [MenuItem(title: "New", id: "1", order: 0)]
        let diff = renderer.diff(old: oldItems, new: newItems)
        XCTAssertEqual(diff.added.count, 1)
        XCTAssertEqual(diff.removed.count, 0)
        XCTAssertEqual(diff.updated.count, 0)
    }

    func testDiffWithRemovedItems() {
        let renderer = Renderer()
        let oldItems = [MenuItem(title: "Old", id: "1", order: 0)]
        let newItems: [MenuItem] = []
        let diff = renderer.diff(old: oldItems, new: newItems)
        XCTAssertEqual(diff.removed.count, 1)
        XCTAssertEqual(diff.added.count, 0)
        XCTAssertEqual(diff.updated.count, 0)
    }

    func testDiffWithUpdatedItems() {
        let renderer = Renderer()
        let oldItems = [MenuItem(title: "Old", id: "1", order: 0)]
        let newItems = [MenuItem(title: "New", id: "1", order: 0)]
        let diff = renderer.diff(old: oldItems, new: newItems)
        XCTAssertEqual(diff.updated.count, 1)
        XCTAssertEqual(diff.added.count, 0)
        XCTAssertEqual(diff.removed.count, 0)
    }

    func testDiffWithNoChanges() {
        let renderer = Renderer()
        let items = [MenuItem(title: "Same", id: "1", order: 0)]
        let diff = renderer.diff(old: items, new: items)
        XCTAssertEqual(diff.added.count, 0)
        XCTAssertEqual(diff.removed.count, 0)
        XCTAssertEqual(diff.updated.count, 0)
    }
}