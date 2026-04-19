// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "lowbar",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "lowbar", type: .dynamic, targets: ["lowbar"]),
    ],
    dependencies: [
        .package(url: "https://github.com/arolang/aro-plugin-sdk-swift.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "lowbar",
            dependencies: [
                .product(name: "AROPluginKit", package: "aro-plugin-sdk-swift"),
            ],
            path: "Sources"
        ),
    ]
)
