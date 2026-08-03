# Changelog

## [1.1.0] - 2026-08-03

### Fixed
- Added `SchedulerDelegate` conformance to `AppDelegate` to resolve type-checking errors
- Fixed `flatMap` type inference issue in `collectAllMenuItems()` by converting to async `for` loop
- Added `@MainActor` to `MenuEngineDelegate` conformance to fix Swift 6 concurrency warnings
- Fixed `(any Module)?` syntax for Swift 6 compatibility in `ModuleManager`
- Fixed `ModuleConfig.enabled` mutability (`let` → `var`) to allow runtime toggling
- Fixed `DiagnosticsCollector` to use `uname()` instead of unavailable `operatingSystemArchitecture` on macOS 14
- Fixed `physicalMemory` (`UInt64`) → `Int64` cast for `formatBytes()`
- Fixed `DiagnosticsView` `ForEach` to use explicit `id: \.id` for `Identifiable` conformance
- Fixed `PreferencesManager.preferences` setter accessibility (`private(set)` → public) for SwiftUI bindings
- Fixed `PreferencesView` binding closure to properly capture TextField value
- Added `Identifiable` conformance to `ModuleConfig` for `ForEach` compatibility

### Changed
- Updated `swift-tools-version` compatibility for Swift 6.3.3 toolchain
- Improved build script with `swiftc -typecheck` fallback when SPM manifest linking fails

### Added
- Diagnostics module with `DiagnosticsManager`, `DiagnosticsCollector`, and `DiagnosticsView`
- Performance monitoring and metrics collection
- System information diagnostics (architecture, CPU count, memory, disk, network)