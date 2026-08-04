# mac-xbar 2.0 — Premium Menu Bar Experience (Production Specification)

## Vision
Build the most polished, native-feeling, lightweight and customizable macOS menu bar utility.

## Default Layout (Ship This)
```
⇣7.3 ⇡1.7
```
Reason: clean, compact, Apple-like, stable width.

## Layout Options
1. Minimal (Default): `⇣7.3 ⇡1.7`
2. Native: `🌐 7.3↓ 1.7↑`
3. Professional: `Wi‑Fi ⇣7.3 ⇡1.7 24ms`
4. Graph: `▁▂▃▅ ⇣7.3`
5. Badge: `[D 7.3] [U 1.7]`
6. Adaptive: auto-select based on space.

## Traffic Styles
- Monochrome (Default)
- Accent Color
- Download/Upload Colors
- Adaptive
- High Contrast

## Badge Styles
- Off (Default)
- Subtle Capsule (recommended)
- Filled Capsule

## Hover Popover
Show download, upload, peak, today, session, IPs, Wi-Fi, latency, jitter, packet loss, health score.

## Dropdown
Live Traffic, Health, Timeline, Usage, Diagnostics, Quick Actions, Modules, Settings.

## Quick Actions
Speed Test, Flush DNS, Restart Wi-Fi, Toggle VPN, Restart Tailscale, Copy IP, Open Router, Export Report.

## Motion
Subtle only: fade, pulse, smooth number transitions. No flashy animations.

## Performance Budget
CPU idle <0.2%, CPU active <0.5%, RAM 15–30MB, Launch <250ms.

## Apple Silicon
Native ARM64, Swift Concurrency, adaptive polling, lazy loading, battery aware.

## Auto Updates
Sparkle 2, signed updates, silent download, stable/beta/nightly, rollback, release notes, delta updates.

## Production Checklist
- Native macOS appearance
- SF Symbols
- SF Pro + monospaced digits
- Stable width
- Retina perfect
- Accessibility
- Local-first
- Privacy-first
- Plugin ready
- AI-ready

## Definition of Excellence
The app should feel like it shipped with macOS while providing professional-grade diagnostics and customization.