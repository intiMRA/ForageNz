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
        // Headless maintenance only. The editor with a window is the CatalogueEditor
        // app target in ForageNZ.xcodeproj.
        .executableTarget(name: "catalogue-tool", dependencies: ["ForageCatalogue"]),
        .testTarget(name: "ForageCatalogueTests", dependencies: ["ForageCatalogue"])
    ]
)
