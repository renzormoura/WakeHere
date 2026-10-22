// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AcordeAquiData",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "AcordeAquiData", targets: ["AcordeAquiData"])
    ],
    dependencies: [
        .package(path: "../AcordeAquiDomain")
    ],
    targets: [
        .target(
            name: "AcordeAquiData",
            dependencies: [
                .product(name: "AcordeAquiDomain", package: "AcordeAquiDomain")
            ],
            path: "Sources/AcordeAquiData"
        ),
        .testTarget(
            name: "AcordeAquiDataTests",
            dependencies: [
                "AcordeAquiData",
                .product(name: "AcordeAquiDomain", package: "AcordeAquiDomain")
            ],
            path: "Tests/AcordeAquiDataTests"
        )
    ]
)
