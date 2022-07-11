// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

private let Propagate = "Propagate"

let package = Package(
    name: Propagate,
    products: [
        .library(
            name: Propagate,
            targets: [Propagate]
        ),
    ],
    dependencies: [
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/Quick/Quick.git", .upToNextMajor(from: "5.0.1")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "10.0.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: Propagate,
            dependencies: []
        ),
        .testTarget(
            name: "PropagateTests",
            dependencies: [
                "Propagate",
                "Quick",
                "Nimble",
            ]
        ),
    ]
)
