// swift-tools-version: 6.0
import PackageDescription

// The catalogue model is not a library any more — it is a folder of the app, at
// `ForageNZ/Catalogue/Model`, compiled straight into ForageNZ and CatalogueEditor as target
// members. That is what lets it use the things a package cannot: the String Catalog, the
// asset catalog, and the `ImageResource`/`ColorResource` symbols Xcode generates from it.
//
// This manifest exists for the command line only. It points a target at that same folder so
// `catalogue-tool` still builds with `swift build` and the model tests still run in about two
// seconds with `swift test`, neither of which needs a simulator. Nothing in the app depends
// on it; delete it and the app still builds.
//
// The catch of compiling one folder two ways: SwiftPM globs the directory, Xcode needs each
// file listed in a target's membership. Add a file to Model/ and `swift test` will see it
// while the app will not. `Tools/check_target_membership.py` fails on that drift.
//
// Anything here that draws — the classification artwork and its localised labels — must stay
// OUT of Model/, because this target compiles without an asset catalog or a String Catalog.
// It lives in `ForageNZ/Components/CatalogueArtwork.swift`, app-side only.
let package = Package(
    name: "CatalogueTooling",
    platforms: [.iOS(.v18), .macOS(.v14)],
    targets: [
        .target(name: "ForageCatalogue", path: "ForageNZ/Catalogue/Model"),
        // Measurement tooling for the photo matcher — the evidence that removed it from the
        // app. Kept apart so the iOS app does not link Vision for code it never calls.
        .target(
            name: "ForageCatalogueTooling",
            dependencies: ["ForageCatalogue"],
            path: "Tools/Catalogue/Tooling"
        ),
        .executableTarget(
            name: "catalogue-tool",
            dependencies: ["ForageCatalogue", "ForageCatalogueTooling"],
            path: "Tools/Catalogue/CLI"
        ),
        .testTarget(
            name: "ForageCatalogueTests",
            dependencies: ["ForageCatalogue"],
            path: "Tools/Catalogue/Tests/ModelTests"
        ),
        .testTarget(
            name: "ForageCatalogueToolingTests",
            dependencies: ["ForageCatalogue", "ForageCatalogueTooling"],
            path: "Tools/Catalogue/Tests/ToolingTests"
        )
    ]
)
