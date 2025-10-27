// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KUpdater",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "KUpdater",
            targets: ["KUpdater"])
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "KUpdater",
            // swiftSettings: [
            //               .define("LIVE_ACTIVITY_ENABLED", .when(platforms: [.iOS], configuration: .release)),
            //                .unsafeFlags([
            //                    "-emit-objc-header",
            //                    "-emit-objc-header-path", "./Headers/KUpdater-Swift.h"
            //                ])
            //           ]

        )

    ]
)
