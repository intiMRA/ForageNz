import ForageCatalogue
import Foundation

// Headless catalogue maintenance. The GUI editor is the `CatalogueEditor` target in
// ForageNZ.xcodeproj; this exists so formatting and checking can run without a window
// (after hand-editing species.json, or in CI).
//
//   swift run catalogue-tool --normalise   rewrite in the canonical shape
//   swift run catalogue-tool --check       report blocking validation issues, non-zero if any

let arguments = CommandLine.arguments

guard let url = CatalogueLocator.resolve() else {
    FileHandle.standardError.write(Data("Couldn't find \(CatalogueLocator.relativePath). Pass --catalogue <path>.\n".utf8))
    exit(1)
}

func loadCatalogue() -> [ForageSpecies] {
    do {
        return try CatalogueFile.load(from: url)
    } catch {
        FileHandle.standardError.write(Data("Couldn't read the catalogue: \(error)\n".utf8))
        exit(1)
    }
}

if arguments.contains("--normalise") {
    let species = loadCatalogue()
    do {
        try CatalogueFile.save(species, to: url)
    } catch {
        FileHandle.standardError.write(Data("Couldn't write the catalogue: \(error)\n".utf8))
        exit(1)
    }
    print("Normalised \(species.count) entries in \(url.path(percentEncoded: false))")
    exit(0)
}

if arguments.contains("--check") {
    let species = loadCatalogue()
    var blocking = 0
    for entry in species {
        for issue in entry.blockingIssues {
            print("\(entry.id) · \(issue.field): \(issue.message)")
            blocking += 1
        }
    }
    let unverified = species.filter { !$0.isVerified }.count
    print("\(species.count) entries · \(blocking) blocking issue(s) · \(unverified) unverified")
    exit(blocking == 0 ? 0 : 1)
}

print("""
catalogue-tool — headless catalogue maintenance

  --normalise            rewrite species.json in the canonical shape
  --check                report blocking validation issues
  --catalogue <path>     use a different catalogue file

The editor with a window is the CatalogueEditor scheme in ForageNZ.xcodeproj.
""")
exit(0)
