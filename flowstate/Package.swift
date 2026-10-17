// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Flowstate",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Flowstate", path: "Sources/Flowstate")
    ]
)
