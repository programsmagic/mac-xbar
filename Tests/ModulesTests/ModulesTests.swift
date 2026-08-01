import XCTest
@testable import Modules

final class ModulesTests: XCTestCase {
    func testNetworkModuleCreation() {
        let module = NetworkModule()
        XCTAssertEqual(module.id, "network")
        XCTAssertEqual(module.name, "Network")
        XCTAssertTrue(module.config.enabled)
    }

    func testSystemModuleCreation() {
        let module = SystemModule()
        XCTAssertEqual(module.id, "system")
        XCTAssertEqual(module.name, "System")
        XCTAssertTrue(module.config.enabled)
    }

    func testNetworkModuleStatus() async throws {
        let module = NetworkModule()
        try await module.initialize()
        let output = try await module.refresh()
        XCTAssertNotNil(output)
        XCTAssertEqual(output.source, "network")
        module.invalidate()
    }

    func testSystemModuleStatus() async throws {
        let module = SystemModule()
        try await module.initialize()
        let output = try await module.refresh()
        XCTAssertNotNil(output)
        XCTAssertEqual(output.source, "system")
        module.invalidate()
    }

    func testModuleConfig() {
        let config = ModuleConfig(id: "test", name: "Test Module", enabled: true, refreshInterval: 30.0, order: 0)
        XCTAssertEqual(config.id, "test")
        XCTAssertEqual(config.name, "Test Module")
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.refreshInterval, 30.0)
    }
}