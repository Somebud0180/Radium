// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RCONCommander",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RCONCore", targets: ["RCONCore"]),
        .executable(name: "RCONCommander", targets: ["RCONCommander"])
    ],
    targets: [
        .target(name: "RCONCore"),
        .executableTarget(name: "RCONCommander", dependencies: ["RCONCore"]),
        .testTarget(name: "RCONCoreTests", dependencies: ["RCONCore"]),
        .testTarget(name: "RCONCommanderTests", dependencies: ["RCONCommander"])
    ]
)
