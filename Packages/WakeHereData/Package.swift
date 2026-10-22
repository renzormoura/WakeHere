// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WakeHereData",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "WakeHereData", targets: ["WakeHereData"])
    ],
    dependencies: [
        .package(path: "../WakeHereDomain")
    ],
    targets: [
        .target(
            name: "WakeHereData",
            dependencies: [
                .product(name: "WakeHereDomain", package: "WakeHereDomain")
            ],
            path: "Sources/WakeHereData"
        ),
        .testTarget(
            name: "WakeHereDataTests",
            dependencies: [
                "WakeHereData",
                .product(name: "WakeHereDomain", package: "WakeHereDomain")
            ],
            path: "Tests/WakeHereDataTests"
        )
    ]
)
