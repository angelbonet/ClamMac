// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClamMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ClamMac", targets: ["ClamMac"]),
    ],
    targets: [
        .target(name: "ClamMacCore"),
        .executableTarget(name: "ClamMac", dependencies: ["ClamMacCore"]),
        .testTarget(name: "ClamMacCoreTests", dependencies: ["ClamMacCore"]),
    ],
    swiftLanguageModes: [.v5]
)
