// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BiasCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v12)          // matches the dev machine, so `swift run quotelint` works with CLT only
    ],
    products: [
        .library(name: "BiasCore", targets: ["BiasCore"]),
        .executable(name: "quotelint", targets: ["QuoteLint"])
    ],
    targets: [
        .target(
            name: "BiasCore",
            path: "Sources/BiasCore"
        ),
        .executableTarget(
            name: "QuoteLint",
            dependencies: ["BiasCore"],
            path: "Sources/QuoteLint"
        )
    ]
)
