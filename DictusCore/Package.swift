// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DictusCore",
    platforms: [.iOS(.v17), .macOS("26.0")],
    products: [
        .library(name: "DictusCore", targets: ["DictusCore"]),
        .executable(name: "polish-harness", targets: ["polish-harness"])
    ],
    targets: [
        .target(name: "DictusCore", path: "Sources/DictusCore"),
        // The #570 / #581 fidelity scorers: proposition recall, person and stance,
        // order, and speaker-state fabrication. Deterministic and model-free.
        //
        // WHY its own target rather than a folder in DictusCore or a file in the
        // harness. It is measurement code, not product code, so it has no business
        // shipping inside the keyboard extension's ~50 MB — but the harness is a
        // macOS-only executable and a test target cannot import one without breaking
        // the iOS Simulator destination `swift test` also runs on (#301). A plain
        // library both can depend on is the only shape that is testable AND absent
        // from the app. Nothing links it into DictusApp or DictusKeyboard.
        .target(name: "PolishFidelity", dependencies: ["DictusCore"], path: "Sources/PolishFidelity"),
        // Off-device polish eval harness (macOS only — needs Apple Intelligence).
        // Runs the REAL pipeline (PolishPipeline + AppleFoundationModelsPolishEngine)
        // on text fixtures, sharing one source of truth with the app. Not built by
        // the iOS app or CI; run locally on a Mac with Apple Intelligence enabled.
        .executableTarget(
            name: "polish-harness",
            dependencies: ["DictusCore", "PolishFidelity"],
            path: "Sources/polish-harness",
            // Undeclared, SwiftPM warns "unhandled file" and that warning is the
            // first line of every committed capture in docs/research/.
            exclude: ["README.md"],
            resources: [.copy("fixtures")]
        ),
        .testTarget(
            name: "DictusCoreTests",
            dependencies: ["DictusCore", "PolishFidelity"],
            path: "Tests/DictusCoreTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
