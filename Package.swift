// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "IRouter",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "IRouter", targets: ["IRouter"]),
    ],
    targets: [
        .target(name: "IRouter"),
        .testTarget(name: "IRouterTests", dependencies: ["IRouter"]),
    ]
)
