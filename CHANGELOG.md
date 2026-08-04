# Changelog

## [3.0.0] - 2026-08-04

### Added
- Wider premium dashboard (460×520) with expanded 18pt content margins so all system/network grids and the speed hero render with comfortable breathing room
- General Settings now shows the live Bundle version instead of a hardcoded string
- Version is sourced from `CFBundleShortVersionString` everywhere (app version, update report, diagnostics, update checker) so it can never drift again
- App store report (`QuickActionsModule` export) now records the real runtime version

### Fixed
- Dashboard content/frame and inner padding rebalanced for the larger canvas; hero cards, Network/Network tabs and the system grid now use the extra width cleanly instead of feeling cramped
- `ProgressBar` (CPU per-core, disk, swap bars) now fills its container's full width and renders at `height: 8` with a color-tinted glow — previously the GeometryReader resolved to a thin/zero width in the per-core row and looked collapsed at `height: 6`

### Performance
- Idle CPU no longer rises with network traffic: `MenuEngine.update` now skips the no-op diff (and its `NSAnimationContext` wrapper) and stops removing/reinserting every menu item on each 1s tick; `setTitle` sets the attributed title directly instead of starting a 0.15s implicit animation every second. Steady idle stays sub-1% even under active throughput.

## [2.1.0] - 2026-08-04

### Added
- Full dashboard popover: 5 tabs (Overview, Network, System, Analytics, Actions) opened on menu-bar click, with right-click preserving the module menu
- Real macOS system data via `SystemInfoCollector`: per-core CPU usage, memory pressure/swap, all disk volumes, battery health/temperature, GPU model, network interface/IP/MAC, system/OS/build info
- iOS-style speed hero: `SpeedView` (arrow + fixed-width number + subtle unit) and `SpeedBarsView` (Control-Center-style throughput bars)
- Live public IP display (NetworkModule cached value with ipify fallback) on the Overview hero, Network tab, and Preferences
- "Open App" button in the dashboard footer; Updates / Quit row
- Live preference wiring: theme, density, show arrows, show units, compact mode, fixed width, and refresh interval apply immediately (no relaunch)
- Search that filters the Settings sidebar
- Modules preferences section now lists all registered modules with working enable/disable toggles
- NetworkStatsStore / SystemStatsStore live polling (1s network, 2s system) with correct lifecycle
- History + AI pipeline fed from real-time speed ticks → Analytics tab, sparkline, and AI Insights now populate
- Adaptive mode now rendered as an honest read-only "Automatic" status row
- Public IP wired into the Preferences Network details (was always "—")
- Native in-popover toast replacing deprecated `NSUserNotification`

### Fixed
- CPU usage showed boot-lifetime average — now computes a true live delta between polls
- Menu-bar CPU read the wrong tick index (NICE vs IDLE), pinning near 100%
- Menu-bar quick actions were dead (`.custom` identifiers didn't match the `QuickAction` enum) — now wired correctly
- "Open Router Admin" produced no gateway (missing `standardOutput` pipe) — now opens the router
- Dashboard disk card labeled *used* space as "free"
- Ping displayed "-1 ms" when measurement failed — now shows "—"
- Update "Last Checked" stayed "Never" even after a clean manual check
- Battery condition rendered "Good" as warning orange
- Segmented tab bar overflow on 380pt width; replaced opaque backgrounds with material for iOS/Control-Center feel
- Removed non-native color emoji (🌐/🔴) from the menu-bar title

### Known
- SSID/RSSI are nil via IORegistry on Apple Silicon (macOS 13+) until CoreWLAN is adopted; shown as "—" gracefully
- The menu-bar public/local IP uses the default-route interface where available; a few interfaces may report empty until a real sample is taken

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