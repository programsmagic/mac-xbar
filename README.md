# mac-xbar

The fastest, lightest, and most extensible native macOS menu bar platform for Apple Silicon (M1--M5+).

Built with Swift 6 and AppKit. Zero unnecessary background work. Privacy-first.

## Features

- Native menu bar experience with incremental diffing
- Built-in modules: Network, System, Developer, Productivity
- Plugin platform with native Swift and script plugin support
- Compact, Detailed, and Developer modes
- Search, Favorites, Pin items
- Keyboard shortcuts and dynamic icons
- Custom themes and layouts
- Apple Shortcuts, AppleScript, URL scheme, CLI support
- Optional AI assistant (opt-in)

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1 or later) recommended
- Xcode 16+
- Swift 6.0+

## Building

```bash
swift build
swift run mac-xbar
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
└── mac-xbar-next-master-plan.md
```

## Architecture

```
App
├── Menu Engine    -- Native NSMenu/NSStatusItem with incremental diffing
├── Scheduler      -- DispatchSourceTimer with event-driven updates
├── Cache          -- TTL-based NSCache
├── Renderer       -- Parse → ViewModel → Diff → Render pipeline
├── Module Manager -- Lazy-load, register, and manage modules
├── Preferences    -- SwiftUI settings, theme support
└── Diagnostics    -- Performance monitoring, logging
```

## License

See LICENSE.txt