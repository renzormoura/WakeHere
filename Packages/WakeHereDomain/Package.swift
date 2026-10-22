// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WakeHereDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "WakeHereDomain", targets: ["WakeHereDomain"])
    ],
    targets: [
        .target(
            name: "WakeHereDomain",
            path: "Sources/WakeHereDomain"
        ),
        .testTarget(
            name: "WakeHereDomainTests",
            dependencies: ["WakeHereDomain"],
            path: "Tests/WakeHereDomainTests"
        )
    ]
)
