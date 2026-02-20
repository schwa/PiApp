// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PiAppSupport",
    platforms: [.macOS(.v15), .iOS(.v18), .visionOS(.v2)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PiAppSupport",
            targets: ["PiAppSupport"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PiAppSupport",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ]
        ),
        .testTarget(
            name: "PiAppSupportTests",
            dependencies: ["PiAppSupport"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
