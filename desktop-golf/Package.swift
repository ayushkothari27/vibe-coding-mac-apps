// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DesktopGolf",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "DesktopGolf", path: "Sources/DesktopGolf")
    ]
)
