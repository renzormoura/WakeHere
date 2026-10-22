// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AcordeAquiDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "AcordeAquiDomain", targets: ["AcordeAquiDomain"])
    ],
    targets: [
        .target(
            name: "AcordeAquiDomain",
            path: "Sources/AcordeAquiDomain"
        ),
        .testTarget(
            name: "AcordeAquiDomainTests",
            dependencies: ["AcordeAquiDomain"],
            path: "Tests/AcordeAquiDomainTests"
        )
    ]
)
