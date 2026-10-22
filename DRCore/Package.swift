// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DRCore",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "DRCore", targets: ["DRCore"])
    ],
    targets: [
        .target(name: "DRCore"),
        .testTarget(name: "DRCoreTests", dependencies: ["DRCore"])
    ]
)
