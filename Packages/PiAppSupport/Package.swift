// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PiAppSupport",
    platforms: [.macOS(.v26), .iOS(.v26), .visionOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PiAppSupport",
            targets: ["PiAppSupport"]
        ),
    ],
    dependencies: [
        .package(path: "/Users/schwa/Projects/PiSwift"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PiAppSupport",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "PiSwiftAI", package: "PiSwift"),
                .product(name: "PiSwiftAgent", package: "PiSwift"),
                .product(name: "PiSwiftCodingAgent", package: "PiSwift"),
            ]
        ),
        .testTarget(
            name: "PiAppSupportTests",
            dependencies: ["PiAppSupport"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
