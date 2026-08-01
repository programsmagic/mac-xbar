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

    func testDeveloperModuleCreation() {
        let module = DeveloperModule()
        XCTAssertEqual(module.id, "developer")
        XCTAssertEqual(module.name, "Developer")
        XCTAssertTrue(module.config.enabled)
    }

    func testProductivityModuleCreation() {
        let module = ProductivityModule()
        XCTAssertEqual(module.id, "productivity")
        XCTAssertEqual(module.name, "Productivity")
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

    func testDeveloperModuleStatus() async throws {
        let module = DeveloperModule()
        try await module.initialize()
        let output = try await module.refresh()
        XCTAssertNotNil(output)
        XCTAssertEqual(output.source, "developer")
        module.invalidate()
    }

    func testProductivityModuleStatus() async throws {
        let module = ProductivityModule()
        try await module.initialize()
        let output = try await module.refresh()
        XCTAssertNotNil(output)
        XCTAssertEqual(output.source, "productivity")
        module.invalidate()
    }

    func testModuleConfig() {
        let config = ModuleConfig(id: "test", name: "Test Module", enabled: true, refreshInterval: 30.0, order: 0)
        XCTAssertEqual(config.id, "test")
        XCTAssertEqual(config.name, "Test Module")
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.refreshInterval, 30.0)
    }

    func testPluginPlatformRegistration() {
        let runtime = PluginRuntime.shared
        XCTAssertNotNil(runtime)
    }

    func testAutomationModule() {
        let automation = AutomationModule.shared
        XCTAssertNotNil(automation)
    }

    func testPrivacyModule() {
        let privacy = PrivacyModule.shared
        XCTAssertFalse(privacy.isTelemetryEnabled)
        XCTAssertTrue(privacy.isLocalStorageOnly)
        XCTAssertTrue(privacy.isPermissionTransparencyEnabled)
        XCTAssertTrue(privacy.isEncryptedSecretsEnabled)
    }

    func testPerformanceModule() {
        let perf = PerformanceModule.shared
        XCTAssertNotNil(perf)
        perf.recordStartup()
        XCTAssertGreaterThanOrEqual(perf.startupTimeMs, 0)
    }

    func testMenuExperience() {
        let experience = MenuExperienceManager.shared
        XCTAssertEqual(experience.currentMode, .detailed)
        XCTAssertTrue(experience.searchEnabled)
        XCTAssertTrue(experience.favoritesEnabled)
        XCTAssertTrue(experience.pinItemsEnabled)
    }
}