# mac-xbar Next --- Product & Engineering Master Plan

## Vision

Build the fastest, lightest, and most extensible native macOS menu bar
platform for Apple Silicon (M1--M5+), combining the flexibility of
plugin-based menu bar tools with a high-performance native core and
premium built-in modules.

## Goals

-   \<10 MB idle memory target
-   \<0.1% CPU while idle
-   Native Apple Silicon (Swift 6 + AppKit)
-   Instant launch
-   Zero unnecessary background work
-   Privacy-first (local by default)
-   Plugin compatibility where practical
-   Beautiful, configurable menu bar experience

------------------------------------------------------------------------

# Pillar 1 -- Core Platform

## Native Engine

-   Swift 6
-   AppKit menu bar application (LSUIElement)
-   Structured concurrency (actors/tasks)
-   DispatchSourceTimer scheduler
-   Modular architecture

## Performance

-   One shared scheduler
-   Event-driven updates
-   Lazy loading
-   Incremental menu diffing
-   Native APIs instead of shell commands
-   Cache layer with TTL
-   Memory pooling for frequently updated models

------------------------------------------------------------------------

# Pillar 2 -- Built-in Modules

## Network

-   Upload/download speed
-   Per-interface selection
-   Auto active-interface detection
-   Session/daily/weekly/monthly usage
-   Latency monitor
-   Public IP
-   Wi-Fi RSSI
-   Noise
-   Link speed
-   DNS tester
-   VPN detection

## System

-   CPU
-   Memory
-   Disk
-   Battery
-   Temperature
-   Fan speed (where available)
-   Uptime
-   Sleep statistics

## Developer

-   Git branch
-   Docker status
-   Kubernetes context
-   VPN
-   Local servers
-   SSH quick actions
-   Clipboard history
-   JSON formatter
-   UUID generator

## Productivity

-   Calendar
-   Focus mode
-   Pomodoro
-   Countdown timers
-   World clocks
-   Notes
-   Quick launcher

------------------------------------------------------------------------

# Pillar 3 -- Menu Experience

-   Compact mode
-   Detailed mode
-   Developer mode
-   Search
-   Favorites
-   Pin items
-   Nested menus
-   Quick actions
-   Drag-and-drop ordering
-   Keyboard shortcuts
-   Dynamic icons
-   Status colors
-   Custom templates

------------------------------------------------------------------------

# Pillar 4 -- Plugin Platform

-   Native Swift plugins
-   Script plugins
-   Sandboxed execution
-   Signed plugins
-   Plugin permissions
-   Plugin marketplace
-   Plugin updates
-   Plugin diagnostics
-   Hot reload

------------------------------------------------------------------------

# Pillar 5 -- Automation

-   Apple Shortcuts
-   AppleScript
-   URL scheme
-   CLI
-   Local REST API (optional)
-   Webhooks
-   Scheduled jobs

------------------------------------------------------------------------

# Pillar 6 -- Intelligence

Optional AI assistant: - Explain system status - Network diagnostics -
Battery recommendations - Plugin generation - Natural-language search

All AI features opt-in.

------------------------------------------------------------------------

# Pillar 7 -- Enterprise

-   Managed configuration
-   MDM support
-   Export/import settings
-   Audit logging
-   Offline mode

------------------------------------------------------------------------

# Pillar 8 -- Privacy

-   No telemetry by default
-   Local storage
-   Permission transparency
-   Encrypted secrets
-   Open architecture

------------------------------------------------------------------------

# Architecture

    App
     ├── Menu Engine
     ├── Scheduler
     ├── Cache
     ├── Renderer
     ├── Module Manager
     ├── Plugin Runtime
     ├── Preferences
     └── Diagnostics

------------------------------------------------------------------------

# Performance Checklist

-   Update only changed menu items
-   Avoid process spawning
-   Adaptive polling
-   Suspend inactive modules
-   Memory budget monitoring
-   Startup profiling
-   Energy impact optimization

------------------------------------------------------------------------

# Premium Features

-   Historical charts
-   Bandwidth alerts
-   Per-app bandwidth
-   Custom themes
-   Widgets
-   Menu layouts
-   Multi-monitor awareness
-   Profiles (Work/Home/Travel)

------------------------------------------------------------------------

# Roadmap

## v1.0

-   Native menu engine
-   Network module
-   Battery
-   CPU
-   Memory
-   Preferences
-   Themes

## v1.1

-   Plugin SDK
-   Marketplace
-   Search
-   Favorites
-   Automation

## v1.2

-   Developer tools
-   Network diagnostics
-   History graphs

## v2.0

-   AI assistant
-   Enterprise features
-   Cloud sync (optional)
-   Community ecosystem

------------------------------------------------------------------------

# Competitive Advantages

Compared with existing menu bar tools:

-   Lower idle resource usage
-   Native-first architecture
-   Built-in modules without plugin hunting
-   Optional plugin ecosystem
-   Better Apple Silicon optimization
-   Strong developer tooling
-   Privacy-first defaults
-   Enterprise-ready
-   Automation APIs
-   Modern UX

------------------------------------------------------------------------

# Success Metrics

-   Idle RAM \<10 MB
-   Idle CPU \<0.1%
-   Startup \<200 ms
-   Battery impact: Minimal
-   100+ built-in capabilities over time
-   Plugin ecosystem
-   Excellent accessibility
-   Regular benchmark suite against competing apps

------------------------------------------------------------------------

# Release Strategy

## Alpha

Core engine and performance validation.

## Beta

Built-in modules, plugin SDK, user feedback.

## RC

Performance hardening, accessibility, localization.

## v1.0

Public release with documentation, website, benchmarks, and migration
guide.

------------------------------------------------------------------------

# Long-Term Vision

Become the default extensible menu bar platform for macOS---combining
the efficiency of a native utility with the extensibility of a developer
framework while remaining exceptionally lightweight.
