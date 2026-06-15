// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacroPlus",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacroPlus",
            path: "Sources/MacroPlus"
        )
    ]
)
