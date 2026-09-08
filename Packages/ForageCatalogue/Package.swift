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
        .executableTarget(name: "CatalogueEditor", dependencies: ["ForageCatalogue"]),
        .testTarget(name: "ForageCatalogueTests", dependencies: ["ForageCatalogue"])
    ]
)
