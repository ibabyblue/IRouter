// swift-tools-version: 6.2
//
//  Package.swift
//  IRouter
//
//  Created by ibabyblue on 2026/05/11.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

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
