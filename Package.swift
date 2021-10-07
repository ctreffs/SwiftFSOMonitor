// swift-tools-version:5.5
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
        .executableTarget(name: "FSOMonitorCLI",
                          dependencies: ["FSOMonitor",
                                         .product(name: "ArgumentParser", package: "swift-argument-parser")]),
        .testTarget(
            name: "FSOMonitorTests",
            dependencies: ["FSOMonitor"])
    ]
)
