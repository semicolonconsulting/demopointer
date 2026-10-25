// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DemoPointer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DemoPointer",
            path: "Sources/DemoPointer"
        )
    ]
)
