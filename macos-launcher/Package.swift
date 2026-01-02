// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOSLauncher",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "macos-launcher", targets: ["LauncherApp"]),
    ],
    dependencies: [
        // UI Testing
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: [
        .executableTarget(
            name: "LauncherApp",
            resources: [
                .process("Assets"),
            ]
        ),
        .testTarget(
            name: "LauncherAppTests",
            dependencies: [
                "LauncherApp",
                "ViewInspector",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: [
                "SnapshotTests/__Snapshots__",
            ]
        ),
    ]
)
