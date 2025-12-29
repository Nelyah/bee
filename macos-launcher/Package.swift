// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOSLauncher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "macos-launcher", targets: ["LauncherApp"])
    ],
    targets: [
        .executableTarget(
            name: "LauncherApp"
        ),
        .testTarget(
            name: "LauncherAppTests",
            dependencies: ["LauncherApp"]
        )
    ]
)
