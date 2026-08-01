// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mac-xbar",
    products: [
        .executable(
            name: "mac-xbar",
            targets: ["App"]
        )
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .target(name: "Core"),
                .target(name: "MenuEngine"),
                .target(name: "Scheduler"),
                .target(name: "Cache"),
                .target(name: "Renderer"),
                .target(name: "Modules"),
                .target(name: "Preferences"),
                .target(name: "Diagnostics"),
            ]
        ),
        .target(
            name: "Core",
            dependencies: []
        ),
        .target(
            name: "MenuEngine",
            dependencies: ["Core"]
        ),
        .target(
            name: "Scheduler",
            dependencies: ["Core"]
        ),
        .target(
            name: "Cache",
            dependencies: ["Core"]
        ),
        .target(
            name: "Renderer",
            dependencies: ["Core", "MenuEngine"]
        ),
        .target(
            name: "Modules",
            dependencies: ["Core", "Cache", "Scheduler"]
        ),
        .target(
            name: "Preferences",
            dependencies: ["Core"]
        ),
        .target(
            name: "Diagnostics",
            dependencies: ["Core"]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["App"]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        ),
        .testTarget(
            name: "MenuEngineTests",
            dependencies: ["MenuEngine"]
        ),
        .testTarget(
            name: "SchedulerTests",
            dependencies: ["Scheduler"]
        ),
        .testTarget(
            name: "CacheTests",
            dependencies: ["Cache"]
        ),
        .testTarget(
            name: "RendererTests",
            dependencies: ["Renderer"]
        ),
        .testTarget(
            name: "ModulesTests",
            dependencies: ["Modules"]
        ),
    ]
)