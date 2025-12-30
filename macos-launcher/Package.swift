// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacOSLauncher",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "macos-launcher", targets: ["LauncherApp"])
    ],
    targets: [
        .executableTarget(
            name: "LauncherApp",
            resources: [
                .process("Assets")
            ]
        ),
        .testTarget(
            name: "LauncherAppTests",
            dependencies: ["LauncherApp"]
        )
    ]
)
