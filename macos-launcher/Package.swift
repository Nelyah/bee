// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOSLauncher",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Library for Xcode app to import
        .library(name: "LauncherAppKit", targets: ["LauncherAppKit"]),
        // CLI executable for development
        .executable(name: "macos-launcher", targets: ["LauncherApp"]),
    ],
    dependencies: [
        // UI Testing
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: [
        // Library containing all the app code (ViewModels, Views, Models, etc.)
        .target(
            name: "LauncherAppKit",
            path: "Sources/LauncherApp",
            exclude: ["LauncherApp.swift"],
            resources: [
                .process("Assets"),
            ]
        ),
        // Executable entry point for CLI usage
        .executableTarget(
            name: "LauncherApp",
            dependencies: ["LauncherAppKit"],
            path: "Sources/LauncherAppMain"
        ),
        .testTarget(
            name: "LauncherAppTests",
            dependencies: [
                "LauncherAppKit",
                "ViewInspector",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: [
                "SnapshotTests/__Snapshots__",
            ]
        ),
    ]
)
