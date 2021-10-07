// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "FSOMonitor",
    products: [
        .library(
            name: "FSOMonitor",
            targets: ["FSOMonitor"]),
        .executable(name: "FSOMonitorCLI",
                    targets: ["FSOMonitorCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.1")
    ],
    targets: [
        .target(
            name: "FSOMonitor",
            dependencies: []),
        .target(name: "FSOMonitorCLI",
                dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser"),
                               "FSOMonitor"]),
        .testTarget(
            name: "FSOMonitorTests",
            dependencies: ["FSOMonitor"])
    ]
)
