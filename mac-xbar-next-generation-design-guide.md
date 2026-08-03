# mac-xbar Next Generation – Product Vision & Design Guide

## Goal
Build the best native macOS menu bar network monitor for Apple Silicon Macs that feels like a first-party system utility.

---

# Design Principles

- Native macOS appearance
- Extremely lightweight
- Instant readability
- Zero visual clutter
- Smooth animations
- Accessibility first
- Battery efficient

---

# Menu Bar

Default compact mode:

```
↓12.4M ↑2.1M
```

Optional modes:

```
↓12.4 ↑2.1 MB/s
⇣12.4 ⇡2.1
↓12.4 • ↑2.1
```

Features:
- Download / Upload
- Auto units (B, KB, MB, GB)
- Configurable refresh (0.5–5 sec)
- SF Symbols or Unicode arrows
- Width stabilization to prevent menu bar jitter
- Optional live activity indicator

---

# Menu Dropdown

## Summary
- Current Download
- Current Upload
- Peak Speeds
- Session Usage
- Today Usage
- Connected Interface
- Public IP
- Local IP
- IPv6
- Gateway
- DNS

## Charts
- 1 minute
- 5 minute
- 30 minute
- 24 hour history

## Interfaces
- Wi-Fi
- Ethernet
- Thunderbolt
- USB adapters
- VPN
- Tailscale
- Loopback (optional)

## Diagnostics
- Ping
- Jitter
- Packet Loss
- DNS latency
- Interface quality

---

# Apple Silicon Features

## Performance
- Native Apple Silicon build
- Swift Concurrency
- Low CPU usage
- Low memory footprint
- Energy efficient timers

## Hardware Awareness

Display:
- Built-in Retina
- External displays
- Dynamic scaling

Network:
- Wi-Fi RSSI
- PHY rate
- Channel
- Band (2.4/5/6 GHz)
- SSID
- BSSID

Power:
- Battery
- Low Power Mode
- Charger state

Thermals (where available)
- CPU usage
- GPU usage
- Memory pressure

Storage
- Read speed
- Write speed
- Free space

Memory
- RAM usage
- Swap
- Compression

CPU
- Efficiency cores
- Performance cores
- Overall utilization

GPU
- GPU activity

---

# Modules

Enable/Disable individually.

- Network Speed
- Internet Status
- Ping
- CPU
- GPU
- Memory
- Disk
- Battery
- Temperature
- Weather (future)
- Clock
- VPN
- Tailscale
- Docker
- GitHub Actions
- Custom Scripts

---

# Appearance

Themes
- System
- Light
- Dark

Density
- Compact
- Normal
- Comfortable

Icon styles
- SF Symbols
- Unicode
- Minimal

Fonts
- System
- Monospaced numbers

Rounded native controls.

---

# Settings

General
- Launch at Login
- Refresh Interval
- Analytics
- Auto Update
- Notifications

Menu Bar
- Compact mode
- Show units
- Show arrows
- Show interface
- Fixed width
- Colorized traffic (optional)

History
- Enable history
- Export CSV
- Reset statistics

---

# Accessibility

- VoiceOver
- Keyboard navigation
- Dynamic Type
- High Contrast
- Reduce Motion
- Color-blind friendly

---

# Performance Targets

CPU:
<0.5%

Memory:
<30 MB

Wakeups:
Minimal

Battery impact:
Negligible

---

# Future

- Network quality score
- Per-process bandwidth
- Menu bar graphs
- Internet outage detection
- ISP monitoring
- Cloud sync
- Shortcuts support
- Apple Intelligence summaries
- Widgets
- Menu Bar customization presets

---

# Recommended UI Layout

Top:
Live speeds

Middle:
Network summary cards

Bottom:
Diagnostics, history, settings

---

# Polish

- Native animations
- Blur materials
- SF Symbols
- Smooth updates
- Stable widths
- Instant opening
- Native context menus
- Beautiful empty/loading states

This should aim to be the most polished open-source macOS menu bar network monitor while remaining lightweight and highly customizable.
