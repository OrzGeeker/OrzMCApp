// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OrzMCKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OrzMCProtocol",
            targets: ["OrzMCProtocol"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/BlueSocket.git", from: "2.0.4")
    ],
    targets: [
        .target(
            name: "OrzMCProtocol",
            dependencies: [
                .product(name: "Socket", package: "BlueSocket")
            ],
            path: "OrzMC/MobileHelper(iOS)/Protocol"
        ),
        .testTarget(
            name: "OrzMCProtocolTests",
            dependencies: ["OrzMCProtocol"],
            path: "Tests/OrzMCProtocolTests"
        )
    ]
)
