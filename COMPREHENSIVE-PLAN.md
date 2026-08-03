# mac-xbar — Complete Project Documentation

**Version:** 2.0.0  
**Date:** 2026-08-03  
**Repository:** https://github.com/programsmagic/mac-xbar  
**Release:** https://github.com/programsmagic/mac-xbar/releases/tag/v2.0.0  
**Status:** Production Ready

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [What It Does](#2-what-it-does)
3. [Requirements](#3-requirements)
4. [Installation](#4-installation)
5. [Architecture](#5-architecture)
6. [Project Structure](#6-project-structure)
7. [How Network Speed Monitoring Works](#7-how-network-speed-monitoring-works)
8. [macOS API Changes 2021–2026](#8-macos-api-changes-20212026)
9. [All Bugs Fixed (v1.1 → v2.0)](#9-all-bugs-fixed-v11--v20)
10. [All Features Implemented](#10-all-features-implemented)
11. [File-by-File Documentation](#11-file-by-file-documentation)
12. [Build & Release Process](#12-build--release-process)
13. [Resource Usage](#13-resource-usage)
14. [Known Limitations](#14-known-limitations)
15. [Roadmap](#15-roadmap)
16. [Commit History](#16-commit-history)

---

## 1. Project Overview

mac-xbar is a **native macOS menu bar network speed monitor** built with Swift 6 and AppKit. It runs as an LSUIElement agent (no Dock icon, menu bar only) and displays real-time upload/download speed directly in the macOS menu bar.

It is a modern Swift rewrite of the original [xbar](https://github.com/matryer/xbar) concept — a lightweight, extensible menu bar platform. Unlike the original (Go-based, plugin-driven), mac-xbar is a pure Swift native app with built-in modules and no plugin dependency.

**Key stats:**
- 3,608 lines of Swift code
- 29 source files across 9 modules
- 132 files changed vs upstream xbar
- 24 commits
- 1.1MB DMG installer
- 33MB physical memory at runtime

---

## 2. What It Does

### Menu Bar (always visible)
Shows live network speed in the menu bar:
```
↓ 1.2M  ↑ 0.3M
```
- Updates every second
- 3-second moving average for smooth display
- Fixed-width formatting prevents jitter
- Shows `—` (em-dash) when no traffic
- Hover tooltip shows detailed speeds

### Menu Dropdown (click icon)
Shows full network information:
- Connected / Disconnected status
- Download speed with color indicator
- Upload speed with color indicator
- Latency (TCP connect to 1.1.1.1)
- Public IP address
- Session totals (total downloaded/uploaded)

### Preferences (Cmd+,)
Shows all settings organized in sections:
- **Live Network Speed** — real-time download, upload, latency, interface, public IP, session totals
- **Appearance** — Theme (System/Light/Dark), Density (Compact/Normal/Comfortable)
- **Menu Bar** — Show Arrows, Show Units, Fixed Width
- **Modules** — Enable/Disable each module individually
- **General** — Refresh Interval, Launch at Login, Analytics

### Background Operation
- App stays running in menu bar continuously
- No Dock icon (LSUIElement)
- Launch at Login via SMAppService (macOS 13+)
- Survives window close — speed always visible

---

## 3. Requirements

| Requirement | Minimum |
|-------------|---------|
| macOS | 14.0 (Sonoma) |
| Architecture | Apple Silicon (M1+) recommended, Intel supported |
| Xcode | 16+ (for building) |
| Swift | 6.0+ |
| Network | Any (Wi-Fi, Ethernet, Cellular) |

---

## 4. Installation

### From DMG (recommended)
1. Download `mac-xbar.dmg` from [Releases](https://github.com/programsmagic/mac-xbar/releases/tag/v2.0.0)
2. Open the DMG
3. Drag `mac-xbar.app` to `/Applications`
4. Open `mac-xbar.app` — right-click and select "Open" if Gatekeeper blocks it
5. (Optional) Enable "Launch at Login" in Preferences

### From source
```bash
git clone git@github.com:programsmagic/mac-xbar.git
cd mac-xbar
bash build.sh build    # Type-check
# Build with Xcode or swiftc
```

### First launch
- macOS may show a Gatekeeper warning (ad-hoc signed)
- Go to **System Settings > Privacy & Security > Open Anyway**
- The app appears as a network icon in the menu bar

---

## 5. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    @main App                            │
│                (mac_xbarApp: App)                        │
│                     │                                   │
│          ┌──────────┴──────────┐                       │
│          │    AppDelegate       │                       │
│          │  (NSApplication)     │                       │
│          └──────────┬──────────┘                       │
│                     │                                   │
│    ┌────────┬───────┴───────┬─────────────┐           │
│    │        │               │             │            │
│  MenuEngine  Scheduler    ModuleManager  Renderer      │
│    │        │               │             │            │
│    │        │          ┌────┴────┐        │            │
│    │        │          │ Modules │        │            │
│    │        │          └─────────┘        │            │
│    │        │                             │            │
│    └────────┴─────────────────────────────┘            │
│                     │                                   │
│          ┌──────────┴──────────┐                       │
│          │   Core Framework    │                       │
│          │  (Models, Types,    │                       │
│          │   Storage, Logger,  │                       │
│          │   Errors, Cache)    │                       │
│          └─────────────────────┘                       │
└─────────────────────────────────────────────────────────┘
```

### Data Flow (per second)

```
NetworkModule.speedTimer (1s)
  → tickSpeed()
    → getInterfaceStats() [sysctl getifaddrs]
    → compute delta bytes / elapsed time
    → 3-second moving average
    → NetworkSpeedObserver.callback
      → AppDelegate.networkModule()
        → MenuEngine.setTitle("↓ 1.2M  ↑ 0.3M")
        → PreferencesManager.updateNetworkStats()
```

### Module System

Each module conforms to the `Module` protocol:
- `id` — unique identifier
- `config` — name, enabled, refreshInterval, order
- `initialize()` — setup
- `refresh()` — produce menu items
- `invalidate()` — teardown
- `setEnabled()` — toggle

Built-in modules:
| Module | Purpose |
|--------|---------|
| NetworkModule | Speed, latency, IP, RSSI, VPN |
| SystemModule | CPU, memory, disk, battery, temperature |
| DeveloperModule | Git, Docker, K8s, servers, ports |
| ProductivityModule | Calendar, focus, pomodoro, clocks |

---

## 6. Project Structure

```
mac-xbar/
├── Sources/
│   ├── App/
│   │   ├── App.swift              # @main, AppDelegate, SettingsWindow
│   │   ├── ModuleManager.swift    # Module registry, toggle, lifecycle
│   │   └── Info.plist             # LSUIElement, version, bundle ID
│   ├── Core/
│   │   ├── Models.swift           # MenuItem, ModuleOutput, AppPreferences, NetworkDisplayStats
│   │   ├── Types.swift            # Theme, Density, ModuleState, type aliases
│   │   ├── ModuleProtocol.swift   # Module protocol, ModuleObserver protocol
│   │   ├── Storage.swift          # JSON file persistence
│   │   ├── Logger.swift           # OSLog-based structured logging
│   │   ├── Errors.swift           # MacXbarError enum
│   │   ├── Diagnostics.swift      # Metric recording
│   │   └── Identifiable.swift     # Custom Identifiable protocol
│   ├── MenuEngine/
│   │   ├── MenuEngine.swift       # NSStatusItem + NSMenu, incremental diffing, animations
│   │   └── NSColor+Hex.swift      # NSColor from hex strings
│   ├── Scheduler/
│   │   └── Scheduler.swift        # DispatchSourceTimer per module
│   ├── Cache/
│   │   └── Cache.swift            # TTL-based NSCache wrapper
│   ├── Renderer/
│   │   └── Renderer.swift         # ModuleOutput → delegate pipeline
│   ├── Modules/
│   │   ├── NetworkModule.swift    # Real sysctl speed, NWPathMonitor, latency, IP
│   │   ├── SystemModule.swift     # CPU, memory, disk, battery via Mach APIs
│   │   ├── DeveloperModule.swift  # Git, Docker, K8s via Process()
│   │   ├── ProductivityModule.swift # Calendar, focus, pomodoro
│   │   ├── AutomationModule.swift # Shortcuts, AppleScript, REST, webhooks
│   │   ├── PluginPlatform.swift   # Plugin protocol, runtime
│   │   ├── MenuExperience.swift   # Favorites, pinning, search
│   │   ├── PrivacyModule.swift    # Telemetry, encryption
│   │   └── PerformanceModule.swift # Memory/CPU budgets, adaptive polling
│   ├── Preferences/
│   │   ├── PreferencesManager.swift # ObservableObject, SMAppService launch-at-login
│   │   └── PreferencesView.swift    # SwiftUI settings with live network stats
│   └── Diagnostics/
│       ├── DiagnosticsManager.swift
│       ├── DiagnosticsCollector.swift  # System info (NWPathMonitor, not deprecated APIs)
│       └── DiagnosticsView.swift
├── Tests/                          # 8 test targets
├── Package.swift                   # Swift 6.0, 8 library targets
├── build.sh                        # Type-check script
├── create-dmg.sh                   # DMG packaging
├── CHANGELOG.md
├── README.md
└── COMPREHENSIVE-PLAN.md           # This file
```

---

## 7. How Network Speed Monitoring Works

### The Problem
Previous approaches failed because:
1. `monitorBandwidth()` was a stub (empty function)
2. `measureLatency()` only measured its own execution time
3. All data collection methods returned nil/0
4. Refresh interval was 30 seconds (too slow)

### The Solution

**Speed measurement** uses `getifaddrs()` to read cumulative byte counters from the kernel:

```swift
func getInterfaceStats() -> InterfaceStats {
    var ifap: UnsafeMutablePointer<ifaddrs>?
    getifaddrs(&ifap)
    
    var totalRx: UInt64 = 0
    var totalTx: UInt64 = 0
    var ptr = firstAddr
    
    while true {
        // Skip loopback, down, and point-to-point interfaces
        if isUp && !isLoopback && !isP2P {
            let ifData = ptr.pointee.ifa_data.assumingMemoryBound(to: if_data.self)
            totalRx += UInt64(ifData.pointee.ifi_ibytes)
            totalTx += UInt64(ifData.pointee.ifi_obytes)
        }
        ptr = ptr.pointee.ifa_next
    }
    return InterfaceStats(rxBytes: totalRx, txBytes: totalTx)
}
```

**Speed calculation** computes delta between readings:

```swift
func tickSpeed() {
    let stats = getInterfaceStats()
    let elapsed = now.timeIntervalSince(previousSpeedTimestamp)
    
    let rxDelta = stats.rxBytes - previousRxBytes
    let txDelta = stats.txBytes - previousTxBytes
    
    let dlSpeed = Double(rxDelta) / elapsed  // bytes per second
    let ulSpeed = Double(txDelta) / elapsed
}
```

**Smoothing** uses a 3-second moving average:

```swift
dlHistory.append(dlSpeed)
if dlHistory.count > 3 { dlHistory.removeFirst() }
smoothedDL = dlHistory.reduce(0, +) / Double(dlHistory.count)
```

**Latency** uses a real TCP connect to Cloudflare's 1.1.1.1:

```swift
func measureLatency() async -> Double {
    let connection = NWConnection(host: "1.1.1.1", port: "80", using: .tcp)
    let start = CFAbsoluteTimeGetCurrent()
    // Wait for .ready state, then compute latency
}
```

**Public IP** fetches from api.ipify.org on launch.

### Key Metrics

| Metric | Source | Update Rate |
|--------|--------|-------------|
| Download speed | getifaddrs byte delta / time | 1 second |
| Upload speed | getifaddrs byte delta / time | 1 second |
| Latency | TCP connect to 1.1.1.1 | 5 seconds |
| Public IP | api.ipify.org | On launch |
| Session total | Cumulative byte counters | Continuous |

---

## 8. macOS API Changes 2021–2026

### macOS 12 Monterey (2021)
- `NWPathMonitor` stable for network path monitoring
- `getifaddrs()` provides 32-bit counters (overflow at ~4.29 GB)
- `LSUIElement = true` unchanged for hiding Dock icon

### macOS 13 Ventura (2022)
- **`MenuBarExtra`** (SwiftUI) introduced — native SwiftUI menu bar API
- **`SMAppService`** replaces deprecated `SMLoginItemSetEnabled` for launch-at-login
- `sysctl(NET_RT_IFLIST2)` provides 64-bit stats but has **4 GiB truncation bug** and **1 KiB batching** (anti-fingerprinting)

### macOS 14 Sonoma (2023)
- **`SCNetworkReachability` deprecated** — all functions
- Local network privacy prompts introduced
- App Sandbox requires network entitlements

### macOS 15 Sequoia (2024)
- Local network privacy bugs: permissions reset after updates
- Content filter API tightening

### macOS 26 Tahoe (2025)
- **Liquid Glass** — menu bar transparent by default
- Icons **must use template rendering** (`.isTemplate = true`)
- `MenuBarExtra` gets automatic Liquid Glass adoption
- Rosetta deprecation notice for Intel apps

### How mac-xbar Adapts

| Feature | Implementation |
|---------|---------------|
| Menu bar icon | Template image (`isTemplate = true`) for Liquid Glass |
| Network monitoring | `getifaddrs()` (works everywhere, no deprecation) |
| Latency | `NWConnection` TCP connect (modern, no deprecated APIs) |
| Launch at login | `SMAppService` (macOS 13+) |
| Network status | `NWPathMonitor` (not deprecated `SCNetworkReachability`) |
| Background | `applicationShouldTerminateAfterLastWindowClosed = false` |

---

## 9. All Bugs Fixed (v1.1 → v2.0)

| # | Bug | Severity | Fix |
|---|-----|----------|-----|
| 1 | Network speed always 0 (stub code) | Critical | Real `getifaddrs()` measurement |
| 2 | `measureLatency()` measured nothing | High | TCP connect to 1.1.1.1 |
| 3 | All network data collection stubs | High | Public IP, latency implemented |
| 4 | 30-second refresh interval | High | Changed to 1 second |
| 5 | Double-refresh bug in refreshAllModules | Medium | Removed redundant refresh |
| 6 | Module toggle in Preferences broken | Medium | Wired to ModuleManager.toggleModule() |
| 7 | `SCNetworkReachability` deprecated | Medium | Replaced with NWPathMonitor |
| 8 | Icon not template (macOS 26 issue) | Medium | `isTemplate = true` |
| 9 | Menu bar width jitter | Low | Fixed-width formatting + stabilizeWidth |
| 10 | SwiftUI quits when window closes | High | `applicationShouldTerminateAfterLastWindowClosed` = false |
| 11 | No auto-start on login | Medium | SMAppService integration |
| 12 | Speed fluctuation | Medium | 3-second moving average |
| 13 | Zero speed shows "0" (width change) | Low | Shows em-dash (—) instead |
| 14 | No hover info | Low | Tooltip shows detailed speeds |

---

## 10. All Features Implemented

### v1.0 (Initial)
- [x] Menu bar app (LSUIElement)
- [x] NSStatusItem with network icon
- [x] NSMenu with incremental diffing
- [x] Module system (Network, System, Developer, Productivity)
- [x] Scheduler with DispatchSourceTimer
- [x] Preferences (SwiftUI)
- [x] Theme support (System/Light/Dark)
- [x] Density modes (Compact/Normal/Comfortable)
- [x] Width stabilization
- [x] Diagnostics module
- [x] CI/CD pipeline (GitHub Actions)
- [x] DMG packaging

### v2.0 (Current)
- [x] Real-time network speed (sysctl getifaddrs)
- [x] Per-second menu bar updates
- [x] 3-second moving average smoothing
- [x] Fixed-width formatting (no jitter)
- [x] Hover tooltip with detailed speeds
- [x] Live Network Speed section in Preferences
- [x] Session usage tracking (total bytes)
- [x] Real latency measurement (TCP connect)
- [x] Public IP detection
- [x] Template images for macOS 26 Liquid Glass
- [x] Smooth animations (NSAnimationContext)
- [x] App stays in background (no quit on window close)
- [x] Launch at Login (SMAppService)
- [x] All deprecated APIs replaced
- [x] All stubs implemented or removed

---

## 11. File-by-File Documentation

### Sources/App/App.swift (247 lines)
**Purpose:** App entry point, AppDelegate, Settings window scene.

**Key code:**
- `mac_xbarApp` — @main SwiftUI App with `@NSApplicationDelegateAdaptor`
- `AppDelegate` — NSApplicationDelegate, SchedulerDelegate, MenuEngineDelegate, NetworkSpeedObserver
- `applicationShouldTerminateAfterLastWindowClosed` → `false` (keeps app alive)
- `networkModule()` callback — receives speed from NetworkModule, updates menu bar
- `formatBarSpeed()` — formats bytes/sec for menu bar display

### Sources/App/ModuleManager.swift (77 lines)
**Purpose:** Thread-safe module registry with NSLock.

**Key code:**
- `register()` / `unregister()` — add/remove modules
- `toggleModule()` — enable/disable and update Preferences
- `registeredModules` — computed property returning all modules

### Sources/Core/Models.swift (174 lines)
**Purpose:** All data models.

**Key structs:**
- `MenuItem` — menu item with id, title, icon, badge, color, action
- `ModuleOutput` — array of MenuItems from a module refresh
- `ModuleConfig` — module configuration (id, name, enabled, refreshInterval)
- `AppPreferences` — all user settings
- `NetworkDisplayStats` — live network info for Preferences display

### Sources/Core/Types.swift (50 lines)
**Purpose:** Type aliases and enums.

**Key types:**
- `Theme` — .system, .light, .dark
- `Density` — .compact, .normal, .comfortable
- `ModuleState` — .active, .paused, .suspended, .error

### Sources/MenuEngine/MenuEngine.swift (356 lines)
**Purpose:** NSStatusItem + NSMenu management with incremental diffing.

**Key features:**
- `setTitle()` — updates menu bar title with animation and dedup
- `setIcon()` — sets template image for macOS 26
- `setTooltip()` — hover tooltip
- `update()` — incremental menu diffing (add/remove/update only changed items)
- `stabilizeWidth()` — prevents menu bar jitter
- `computeDiff()` / `applyDiff()` — surgical NSMenu modification
- `speedFont` — monospaced digits for stable width

### Sources/Modules/NetworkModule.swift (400 lines)
**Purpose:** Real network speed monitoring.

**Key features:**
- `getInterfaceStats()` — reads byte counters via getifaddrs
- `tickSpeed()` — 1-second timer, computes delta, applies moving average
- `NetworkSpeedObserver` protocol — pushes speed to AppDelegate
- `measureLatency()` — TCP connect to 1.1.1.1
- `fetchPublicIP()` — api.ipify.org
- `formatSpeedShort()` / `formatBytes()` — human-readable formatting
- Session tracking — cumulative bytes since launch

### Sources/Preferences/PreferencesManager.swift (70 lines)
**Purpose:** ObservableObject singleton for user preferences.

**Key features:**
- `@Published preferences` — auto-saves on change
- `@Published networkStats` — live network info
- `updateNetworkStats()` — called from speed observer
- `syncLaunchAtLogin()` — SMAppService registration
- Storage via JSON files in ~/Library/Application Support/mac-xbar/

### Sources/Preferences/PreferencesView.swift (250 lines)
**Purpose:** SwiftUI settings UI.

**Key sections:**
- Live Network Speed — colored icons, monospaced values
- Appearance — segmented Theme/Density pickers
- Menu Bar — toggles for arrows, units, fixed width
- Modules — toggle switches wired to ModuleManager
- General — refresh interval, launch at login, analytics

### Sources/Diagnostics/DiagnosticsCollector.swift (142 lines)
**Purpose:** System information collection.

**Key changes:**
- Replaced deprecated `SCNetworkReachability` with `NWPathMonitor`
- Collects: macOS version, architecture, CPU, memory, disk, network, app version

### Sources/Modules/SystemModule.swift (268 lines)
**Purpose:** CPU, memory, disk, battery, temperature, fan, uptime.

**Key APIs:**
- `host_statistics()` for CPU ticks
- `vm_statistics` for memory
- `FileManager` for disk
- `IOKit` for temperature/fan

### Sources/Modules/DeveloperModule.swift (223 lines)
**Purpose:** Developer tools — Git, Docker, K8s, servers, UUID.

**Key APIs:**
- `Process()` for shell commands
- Socket `connect()` for port scanning

### build.sh (90 lines)
**Purpose:** Type-check script.

**Commands:**
- `bash build.sh build` — type-check source files
- `bash build.sh test` — type-check source + test files
- `bash build.sh all` — type-check everything
- `bash build.sh ci` — full CI pipeline

### create-dmg.sh (111 lines)
**Purpose:** Create signed DMG installer.

**Steps:**
1. Compile binary
2. Create .app bundle with Info.plist
3. Generate icon from PNG
4. Code sign (ad-hoc)
5. Create DMG with Applications symlink

---

## 12. Build & Release Process

### Local build
```bash
# Type-check only
bash build.sh build

# Full build with SPM (requires Xcode)
swift build -c release

# Direct swiftc compilation
find Sources -name "*.swift" -print0 | xargs -0 swiftc \
  -target arm64-apple-macosx14.0 \
  -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk \
  -o mac-xbar

# Create DMG
bash create-dmg.sh
```

### Release process
```bash
# 1. Commit changes
git add .
git commit -m "feat: description"

# 2. Push
git push origin master

# 3. Tag
git tag -a v2.0.0 -m "Release v2.0.0"
git push origin v2.0.0

# 4. Create DMG
bash create-dmg.sh

# 5. Create GitHub release with DMG
gh release create v2.0.0 mac-xbar.dmg --title "v2.0.0" --notes "..."
```

### CI/CD
GitHub Actions workflow (`.github/workflows/build.yml`):
1. On push to master — type-check source + tests
2. On release created — build DMG, upload as release asset

---

## 13. Resource Usage

| Metric | Value | Target |
|--------|-------|--------|
| Physical footprint | 33 MB | < 50 MB |
| CPU (idle) | 2-5% | < 10% |
| CPU (active) | 5-10% | < 15% |
| Memory (RSS) | 92 MB | — |
| Binary size | 1.6 MB | < 5 MB |
| DMG size | 1.1 MB | < 10 MB |
| Threads | 4-5 | < 10 |

The app uses `getifaddrs()` which is kernel-level (no network I/O for stats), so it doesn't trigger local network privacy prompts.

---

## 14. Known Limitations

1. **32-bit counters** — `getifaddrs()` uses 32-bit `ifi_ibytes`/`ifi_obytes`. On connections faster than ~340 MB/s, counters overflow within ~12 seconds. For most users this is fine; for 10Gbps+ connections, `sysctl(IFMIB_IFDATA)` would be needed.

2. **All interfaces combined** — Speed is summed across all active interfaces (Wi-Fi + Ethernet + VPN). Cannot show per-interface speed.

3. **Ad-hoc signed** — App is not notarized by Apple. Users must manually approve in System Settings.

4. **No Dock icon** — By design (LSUIElement). App is menu bar only.

5. **Preferences window** — Must be opened via menu or `Cmd+,`. No dedicated settings button in menu bar.

---

## 15. Roadmap

### v2.1 (planned)
- [ ] Per-interface speed selection
- [ ] Wi-Fi RSSI and signal strength
- [ ] Historical speed charts (1min, 5min, 1hr)
- [ ] Bandwidth alerts (notify when speed drops)
- [ ] Notarized build for distribution

### v2.2 (planned)
- [ ] System module live updates (CPU, memory, disk)
- [ ] Battery health monitoring
- [ ] Temperature sensors
- [ ] Fan speed

### v3.0 (future)
- [ ] Plugin SDK for third-party modules
- [ ] Widgets (macOS 14+)
- [ ] Apple Shortcuts integration
- [ ] Cloud sync for settings

---

## 16. Commit History

```
23172b9 fix: app stays running in background, auto-start on login
5c1e37d chore: update DMG script version to 2.0.0
5260b82 fix: tooltip on hover, fixed-width speed format, em-dash for zero
7bcdcd5 fix: smooth speed display with 3-second moving average
4461234 fix: shorter menu bar display, fixed-width default, smoother animations
03a6864 feat: v2.0.0 — real-time network speed, modern macOS support, UI overhaul
fd0281b Fix DeveloperModule pasteboard crash on background thread
2261a55 UI polish: themes, density modes, menu bar speed indicator, width stabilization
6de12e6 Add network speed indicator in menu bar title
ed2c6ff Fix SettingsWindow: change class to struct for SwiftUI Scene requirement
4c9fbe2 Add app icon, ad-hoc code signing, and fix DMG build
ff2f9d3 Fix CI workflow: use build script instead of swift build/test
4774e08 Fix CI workflow YAML indentation for dmg job
7d942cd Release v1.1.0
a5d82a2 Add Diagnostics module tests and update Package.swift
e4361a6 Add Diagnostics module with DiagnosticsManager, DiagnosticsCollector, and DiagnosticsView
8573786 Update CI workflow to build DMG and upload to releases
d08ee5a Clean up build script: suppress SPM noise, add check_typecheck helper
73239d3 Improve build script with profiling, parallel type-checking, and CI mode
6451ac3 Fix App.swift type-checking errors and Renderer/Scheduler/ModuleManager issues
f3a325c Simplify Package.swift for broken SPM toolchain compatibility
084415b Fix type-checking errors across all Swift source files
a448f43 Add build plan, CI workflow, and build script
7263f89 Expand app per master plan: System, Developer, Productivity, Menu Experience, Plugin Platform, Automation, Privacy, Performance modules
dd27c69 Initial scaffold: mac-xbar Next Swift 6 + AppKit project
```

---

## Quick Reference

### Menu bar format
```
↓ 1.2M  ↑ 0.3M     ← active traffic
↓  —    ↑  —       ← no traffic (fixed width)
```

### Hover tooltip
```
Download: 1.2 MB/s
Upload: 300 KB/s
```

### Preferences sections
- Live Network Speed (real-time)
- Appearance (theme, density)
- Menu Bar (arrows, units, fixed width)
- Modules (enable/disable)
- General (interval, launch, analytics)

### Build commands
```bash
bash build.sh build    # Type-check
bash create-dmg.sh     # Create DMG
gh release create ...  # Upload to GitHub
```
