# mac-xbar

The fastest, lightest, and most extensible native macOS menu bar platform for Apple Silicon (M1--M5+).

Built with Swift 6 and AppKit. Zero unnecessary background work. Privacy-first.

## Features

- **Real-time network speed** in menu bar (per-second updates via sysctl)
- Live network stats in Preferences (download, upload, latency, interface, public IP, session usage)
- Native menu bar experience with incremental diffing
- Built-in modules: Network, System, Developer, Productivity
- Plugin platform with native Swift and script plugin support
- Compact, Detailed, and Developer modes
- Search, Favorites, Pin items
- Keyboard shortcuts and dynamic icons
- Custom themes and density modes (Compact/Normal/Comfortable)
- Monospaced digits for stable menu bar width
- Template icons for macOS 26 Liquid Glass compatibility
- Apple Shortcuts, AppleScript, URL scheme, CLI support

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1 or later) recommended
- Xcode 16+
- Swift 6.0+

## Building

```bash
bash build.sh build    # Type-check source files
bash build.sh test     # Type-check source + test files
bash build.sh all      # Type-check everything
bash build.sh ci       # Full CI pipeline
```

## Releasing

To create a release `.dmg`:

1. Update the version in `Sources/App/Info.plist`, `.github/workflows/build.yml`, and `create-dmg.sh`
2. Commit and tag: `git tag -a v2.0.0 -m "release v2.0.0"`
3. Push the tag: `git push origin v2.0.0`
4. The CI workflow will automatically build, sign, and upload the DMG

Or build locally:

```bash
bash build.sh build
bash create-dmg.sh
```

## Project Structure

```
mac-xbar/
├── Sources/
│   ├── App/              # App entry point, AppDelegate, ModuleManager
│   ├── Core/             # Core types, models, storage, errors, logging
│   ├── MenuEngine/       # NSMenu/NSStatusItem with incremental diffing
│   ├── Scheduler/        # DispatchSourceTimer-based event scheduler
│   ├── Cache/            # TTL-based NSCache layer
│   ├── Renderer/         # Parse → ViewModel → Diff → Render pipeline
│   ├── Modules/          # Built-in modules (Network, System, etc.)
│   ├── Preferences/      # SwiftUI settings UI and preferences manager
│   └── Diagnostics/      # Performance monitoring and metrics
├── Tests/
├── Package.swift
└── COMPREHENSIVE-PLAN.md
```

## Architecture

```
App
├── Menu Engine       -- Native NSMenu/NSStatusItem with incremental diffing
├── Scheduler         -- DispatchSourceTimer with event-driven updates
├── Cache             -- TTL-based NSCache
├── Renderer          -- Parse → ViewModel → Diff → Render pipeline
├── Module Manager    -- Lazy-load, register, and manage modules
├── Preferences       -- SwiftUI settings, theme support, live network stats
└── Diagnostics       -- Performance monitoring, logging
```

## Network Speed Monitoring

The app uses `sysctl` to read network interface byte counters directly from the kernel. A dedicated 1-second timer computes the delta between readings to display real-time throughput in the menu bar.

- **Menu bar format:** `↓12.4K ↑2.1M` (monospaced digits, auto-scaled units)
- **Preferences panel:** Live download, upload, latency, interface, public IP, session totals
- **Latency:** Measured via TCP connect to 1.1.1.1 every 5 seconds
- **Public IP:** Fetched from api.ipify.org on launch

## License

See LICENSE.txt
