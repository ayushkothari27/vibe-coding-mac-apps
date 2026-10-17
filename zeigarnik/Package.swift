// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Zeigarnik",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Zeigarnik", path: "Sources/Zeigarnik")
    ]
)
