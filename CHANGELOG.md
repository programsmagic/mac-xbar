# Changelog

## [2.0.0] - 2026-08-03

### Added
- Real per-second network speed display in menu bar (sysctl-based throughput measurement)
- Live Network Speed section in Preferences with download, upload, latency, interface, public IP, session usage
- Dedicated 1-second speed timer for real-time menu bar updates
- Session usage tracking (total bytes downloaded/uploaded since launch)
- Template images for macOS 26 Liquid Glass compatibility
- Monospaced digits for speed values to prevent menu bar jitter
- `statusItem.behavior = .isStationary` to prevent menu bar reflow
- `NetworkSpeedObserver` protocol for real-time speed push to AppDelegate
- `NetworkDisplayStats` model for live network info display
- Signal strength-based color coding for Wi-Fi RSSI (green/orange/red)

### Fixed
- Network speed was always 0 (monitorBandwidth was a stub) — now uses real sysctl IFF_DATA
- Double-refresh bug in refreshAllModules() — modules were refreshed twice per tick
- Module toggle in Preferences was `.constant()` — now actually enables/disables modules
- `measureLatency()` only measured its own execution time — now uses real TCP connect to 1.1.1.1
- Refresh interval changed from 30s to 1s for real-time speed display
- Deprecated `SCNetworkReachability` replaced with `NWPathMonitor` in DiagnosticsCollector

### Changed
- Default update interval changed from 60s to 1s
- NetworkModule refreshInterval changed from 30s to 1s
- Menu bar title format: `↓X.XK ↑X.XK` (monospaced, auto-scaled units)
- Preferences window default size increased to 420x600
- All SF Symbol icons now use template rendering for proper dark/light mode
- Version bumped to 2.0.0

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