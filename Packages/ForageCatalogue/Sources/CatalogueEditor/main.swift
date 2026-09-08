import ForageCatalogue
import Foundation

// `--normalise` rewrites the catalogue in the canonical shape CatalogueFile.encoder()
// produces and exits, without opening a window. Run it after hand-editing species.json so
// the editor's next save is a one-entry diff rather than a whole-file reformat.
if CommandLine.arguments.contains("--normalise") {
    let url = CatalogueLocator.resolve()
    do {
        let species = try CatalogueFile.load(from: url)
        try CatalogueFile.save(species, to: url)
        print("Normalised \(species.count) entries in \(url.path(percentEncoded: false))")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("Normalise failed: \(error)\n".utf8))
        exit(1)
    }
}

CatalogueEditorApp.main()
