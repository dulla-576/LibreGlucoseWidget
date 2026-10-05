// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LibreGlucoseCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v26)
    ],
    products: [
        .library(name: "LibreGlucoseCore", targets: ["LibreGlucoseCore"])
    ],
    targets: [
        .target(name: "LibreGlucoseCore"),
        .testTarget(
            name: "LibreGlucoseCoreTests",
            dependencies: ["LibreGlucoseCore"],
            resources: [.process("Fixtures")]
        )
    ]
)
