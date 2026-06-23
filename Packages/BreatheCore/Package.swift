// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BreatheCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BreatheCore", targets: ["BreatheCore"])
    ],
    targets: [
        .target(
            name: "BreatheCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "BreatheCoreTests",
            dependencies: ["BreatheCore"]
        )
    ]
)
