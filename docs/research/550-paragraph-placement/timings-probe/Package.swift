// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "probe",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", .upToNextMinor(from: "0.12.3"))
    ],
    targets: [
        .executableTarget(name: "probe", dependencies: [.product(name: "FluidAudio", package: "FluidAudio")])
    ]
)
