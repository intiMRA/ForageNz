import AppKit
import DesignLibrary
import ForageCatalogue
import SwiftUI
import UniformTypeIdentifiers

/// Photo management for one entry: import, caption, credit, reorder by deletion, and the
/// running size cost — since these ship inside the app.
struct PhotoSectionView: View {
    let species: ForageSpecies
    let photoDirectory: URL?
    let onChange: (ForageSpecies) -> Void
    let onRemovePhoto: (SpeciesPhoto) -> Void

    @State private var importError: String?

    private var wantedPhotoCount: Int {
        CataloguePhotos.recommendedCount(hasDeadlyLookalike: species.highestLookalikeRisk == .deadly)
    }

    /// Says why the count matters: nobody in the bush can look anything up.
    private var emptyStateGuidance: String {
        let base = "No photos yet. Aim for \(wantedPhotoCount): whole plant, leaf or frond detail, "
            + "the diagnostic feature, and whatever it gets confused with."
        let offline = " Assume no signal: these must stand alone, because the web link may "
            + "not load where it matters."
        return species.highestLookalikeRisk == .deadly
            ? base + " It has a deadly lookalike, so it needs more than usual." + offline
            : base + offline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .small) {
            if photoDirectory == nil {
                Text("No catalogue directory, so photos can't be imported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if species.photos.isEmpty {
                Text(emptyStateGuidance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(species.photos.enumerated()), id: \.element.fileName) { index, photo in
                photoRow(index: index, photo: photo)
            }

            HStack(spacing: .small) {
                Button("Add photos…", systemImage: "photo.badge.plus") { pickPhotos() }
                    .buttonStyle(.borderless)
                    .disabled(photoDirectory == nil)

                if !species.photos.isEmpty {
                    Text(sizeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let importError {
                Label(importError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: .xxSmall) {
                Text("More photos on the web")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    "https://inaturalist.nz/taxa/…",
                    text: Binding(
                        get: { species.moreImagesURL?.absoluteString ?? "" },
                        set: { text in
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            onChange(species.with(moreImagesURL: trimmed.isEmpty ? .some(nil) : URL(string: trimmed)))
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                Text("Useful for planning, and in the field when there is signal — so never the only place something important lives.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, .xxxSmall)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            loadDropped(providers)
            return true
        }
    }

    private func photoRow(index: Int, photo: SpeciesPhoto) -> some View {
        HStack(alignment: .top, spacing: .small) {
            thumbnail(for: photo)

            VStack(alignment: .leading, spacing: .xxSmall) {
                TextField("Caption — which feature does this show?", text: Binding(
                    get: { photo.caption },
                    set: { replace(index, caption: $0) }
                ))
                .textFieldStyle(.roundedBorder)

                TextField("Credit — © Name, some rights reserved (CC BY)", text: Binding(
                    get: { photo.credit },
                    set: { replace(index, credit: $0) }
                ))
                .textFieldStyle(.roundedBorder)

                TextField("Source URL", text: Binding(
                    get: { photo.sourceURL?.absoluteString ?? "" },
                    set: { replace(index, sourceURL: URL(string: $0.trimmingCharacters(in: .whitespaces))) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.caption)

                HStack(spacing: .xSmall) {
                    Text(photo.fileName)
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.secondary)
                    Text(fileSize(for: photo))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                remove(index: index, photo: photo)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .help("Remove photo — the file is deleted when you save")
        }
        .padding(.all, .small)
        .background(.quaternary.opacity(Layout.cardBackgroundOpacity), in: EditorLayout.insetShape)
    }

    @ViewBuilder
    private func thumbnail(for photo: SpeciesPhoto) -> some View {
        if let photoDirectory,
           let image = NSImage(contentsOf: photoDirectory.appending(path: photo.fileName)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: EditorLayout.thumbnailSize, height: EditorLayout.thumbnailSize)
                .clipShape(EditorLayout.insetShape)
        } else {
            EditorLayout.insetShape
                .fill(.quaternary)
                .frame(width: EditorLayout.thumbnailSize, height: EditorLayout.thumbnailSize)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
                .allowsHitTesting(false)
        }
    }

    // MARK: - Size reporting

    private var sizeSummary: String {
        let bytes = species.photos.reduce(0) { $0 + rawSize(of: $1) }
        return "\(species.photos.count) photo(s) · \(bytes / 1024) KB"
    }

    private func fileSize(for photo: SpeciesPhoto) -> String {
        let bytes = rawSize(of: photo)
        return bytes == 0 ? "missing" : "\(bytes / 1024) KB"
    }

    private func rawSize(of photo: SpeciesPhoto) -> Int {
        guard let photoDirectory else { return 0 }
        let path = photoDirectory.appending(path: photo.fileName).path
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return (attributes?[.size] as? Int) ?? 0
    }

    // MARK: - Mutation

    private func replace(
        _ index: Int,
        caption: String? = nil,
        credit: String? = nil,
        sourceURL: URL?? = nil
    ) {
        var next = species.photos
        let current = next[index]
        next[index] = SpeciesPhoto(
            fileName: current.fileName,
            caption: caption ?? current.caption,
            credit: credit ?? current.credit,
            sourceURL: sourceURL ?? current.sourceURL
        )
        onChange(species.with(photos: next))
    }

    private func remove(index: Int, photo: SpeciesPhoto) {
        var next = species.photos
        next.remove(at: index)
        onChange(species.with(photos: next))
        onRemovePhoto(photo)
    }

    // MARK: - Import

    private func pickPhotos() {
        guard let photoDirectory else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Import"
        panel.message = "Photos are downscaled to \(CataloguePhotos.maximumPixelSize)px and re-encoded as HEIC."

        guard panel.runModal() == .OK else { return }
        importFiles(panel.urls, into: photoDirectory)
    }

    private func loadDropped(_ providers: [NSItemProvider]) {
        guard let photoDirectory else { return }
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in importFiles([url], into: photoDirectory) }
            }
        }
    }

    private func importFiles(_ urls: [URL], into directory: URL) {
        var added = species.photos
        var failures: [String] = []

        for url in urls {
            do {
                let photo = try PhotoImporter.importPhoto(
                    from: url, speciesId: species.id, existing: added, into: directory
                )
                added.append(photo)
            } catch {
                failures.append(error.errorDescription ?? String(describing: error))
            }
        }

        if added.count != species.photos.count {
            onChange(species.with(photos: added))
        }
        importError = failures.isEmpty ? nil : failures.joined(separator: "\n")
    }
}
