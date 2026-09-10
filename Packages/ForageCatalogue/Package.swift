// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ForageCatalogue",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "ForageCatalogue", targets: ["ForageCatalogue"])
    ],
    targets: [
        .target(name: "ForageCatalogue"),
        // Measurement tooling for the photo matcher — the evidence that removed it from the
        // app. Kept apart so the iOS app does not link Vision for code it never calls.
        .target(name: "ForageCatalogueTooling", dependencies: ["ForageCatalogue"]),
        .executableTarget(
            name: "catalogue-tool",
            dependencies: ["ForageCatalogue", "ForageCatalogueTooling"]
        ),
        .testTarget(name: "ForageCatalogueTests", dependencies: ["ForageCatalogue"]),
        .testTarget(
            name: "ForageCatalogueToolingTests",
            dependencies: ["ForageCatalogue", "ForageCatalogueTooling"]
        )
    ]
)
