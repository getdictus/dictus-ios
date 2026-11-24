// swift-tools-version: 5.9
import PackageDescription

// The swipe decoder bench (#948): synthetic swipes through DictusCore's `SwipeDecoder`, on
// the Mac. Build it in release (`run.sh` does): a debug build decodes about fifty times
// slower and its times say nothing about the keyboard's.
let package = Package(
    name: "swipe-bench",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(path: "../../DictusCore")
    ],
    targets: [
        .executableTarget(
            name: "swipe-bench",
            dependencies: [.product(name: "DictusCore", package: "DictusCore")]
        )
    ]
)
