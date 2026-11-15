// swift-tools-version: 5.9
import PackageDescription

// Exact pins: the versions DictusApp resolves today, so the bench decodes with the
// same engines the app ships.
let package = Package(
    name: "closing-phrase-bench",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", exact: "0.18.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.8"),
        .package(path: "../../DictusCore")
    ],
    targets: [
        .executableTarget(
            name: "closing-phrase-bench",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "DictusCore", package: "DictusCore")
            ]
        )
    ]
)
