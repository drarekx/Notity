// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Notity",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Notity",
            path: "Sources/Notity"
        )
    ]
)
