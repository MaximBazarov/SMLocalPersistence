// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SMLocalPersistence",
    platforms: [
        .macOS(.v12),
        .iOS(.v17),
    ],
    products: [
        .library(name: "SMLocalPersistence", targets: ["SMLocalPersistence"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/MaximBazarov/StateManagement.git",
            from: "0.9.4"
        ),
    ],
    targets: [
        .target(
            name: "SMLocalPersistence",
            dependencies: ["StateManagement"],
            path: "Sources"
        ),
        .testTarget(
            name: "SMLocalPersistenceTests",
            dependencies: [
                "SMLocalPersistence",
                .product(name: "StateManagementTestingSupport", package: "StateManagement"),
            ],
            path: "Tests"
        ),
    ]
)
