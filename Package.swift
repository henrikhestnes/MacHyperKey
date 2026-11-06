// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacHyperKey",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MacHyperKey", targets: ["MacHyperKey"])],
    targets: [
        .target(name: "MacHyperKeyCore"),
        .executableTarget(name: "MacHyperKey", dependencies: ["MacHyperKeyCore"]),
        .testTarget(name: "MacHyperKeyCoreTests", dependencies: ["MacHyperKeyCore"])
    ]
)
