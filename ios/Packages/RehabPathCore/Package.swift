// swift-tools-version:5.9
import PackageDescription

// Platform-independent domain logic for the RehabPath iOS app.
// Keep this package free of UIKit/SwiftUI so it builds and tests on Linux CI.
let package = Package(
    name: "RehabPathCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RehabPathCore", targets: ["RehabPathCore"])
    ],
    targets: [
        .target(name: "RehabPathCore"),
        .testTarget(name: "RehabPathCoreTests", dependencies: ["RehabPathCore"])
    ]
)
