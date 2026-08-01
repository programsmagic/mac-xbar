# Build Plan for mac-xbar

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 16+
- Swift 6.0+
- Apple Silicon (M1 or later) recommended
- Git

## Build Steps

### 1. Clone the repository

```bash
git clone https://github.com/programsmagic/mac-xbar.git
cd mac-xbar
```

### 2. Resolve Swift dependencies

```bash
swift package resolve
```

### 3. Build the project

```bash
swift build
```

### 4. Run tests

```bash
swift test
```

### 5. Run the app

```bash
swift run mac-xbar
```

### 6. Create an Xcode project (for GUI development)

```bash
swift package generate-xcodeproj
```

Or open the package directly in Xcode:

```bash
xed .
```

## Build Configuration

### Debug Build

```bash
swift build -c debug
```

### Release Build

```bash
swift build -c release
```

### Custom Build Flags

```bash
swift build -Xswiftc -DDEBUG -Xswiftc -DVERBOSE_LOGGING
```

## CI/CD Pipeline

See `.github/workflows/build.yml` for the CI configuration.

The CI pipeline:
1. Checks out the code
2. Resolves dependencies
3. Builds the project
4. Runs tests
5. Runs linting (swiftlint if available)
6. Archives the app for distribution

## Distribution

### Creating a .app Bundle

```bash
swift build -c release
```

The built app will be at `.build/release/mac-xbar`.

### Creating a .dmg Installer

Use `create-dmg` or a custom script to package the app into a DMG.

### Notarization

For macOS 14+, notarization is required for distribution outside the App Store.

## Performance Targets

- Idle RAM: <10 MB
- Idle CPU: <0.1%
- Startup Time: <200 ms
- Battery Impact: Minimal

## Code Signing

The app must be signed with a valid Apple Developer certificate for distribution.

## Troubleshooting

### Build fails with "No such module"

Run `swift package resolve` to fetch dependencies.

### App crashes on launch

Check Console.app for crash logs. Ensure macOS 14+ is installed.

### Permission errors

The app requires access to:
- Network (for module updates)
- File system (for plugin storage)
- Accessibility (for menu bar integration)