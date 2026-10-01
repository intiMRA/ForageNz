import AppKit
import DesignLibrary
import SwiftUI
import UniformTypeIdentifiers

/// Photo management for one entry: import, caption, credit, reorder by deletion, and the
/// running size cost — since these ship inside the app.
struct PhotoSectionView: View {
    let species: ForageSpecies
    let photoDirectory: URL?
    /// Where the photo fetcher's candidates wait, when there are any.
    let stagingDirectory: URL?
    /// The catalogue on disk, which the photo fetcher reads when asked for more candidates.
    let catalogueURL: URL?
    let onChange: (ForageSpecies) -> Void
    let onRemovePhoto: (SpeciesPhoto) -> Void

    @State private var importError: String?
    @State private var staged: [StagedPhoto] = []
    @State private var isFetching = false
    /// What the last fetch reported — including "nothing usable", which is a real answer for
    /// an endemic with few observers and must not look like a failure.
    @State private var fetchReport: String?

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

                Button("Fetch more…", systemImage: "arrow.down.circle") { fetchMore() }
                    .buttonStyle(.borderless)
                    .disabled(isFetching || catalogueURL == nil || stagingDirectory == nil)
                    .help(fetchHelp)

                if isFetching {
                    ProgressView()
                        .controlSize(.small)
                }

                if !species.photos.isEmpty {
                    Text(sizeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let fetchReport {
                Text(fetchReport)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let importError {
                Label(importError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !staged.isEmpty {
                Divider()
                stagedTray
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
        .task(id: species.id) { reloadStaged() }
    }

    // MARK: - Staged candidates

    /// Candidates the fetcher downloaded, each awaiting a verdict.
    ///
    /// Keeping is the deliberate act, not discarding: a reviewer who loses interest halfway
    /// down the tray ships nothing, which is the right way round. Rejection is the normal
    /// case anyway — liberty cap kept 6 of 14, weraroa 6 of 25.
    @ViewBuilder
    private var stagedTray: some View {
        VStack(alignment: .leading, spacing: .small) {
            Text("\(staged.count) staged candidate(s)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Downloaded and encoded, but not in the catalogue. Reject any frame that argues against this entry's own identification or habitat — that is worse than no photo at all.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(staged) { candidate in
                stagedRow(candidate)
            }
        }
    }

    private func stagedRow(_ candidate: StagedPhoto) -> some View {
        HStack(alignment: .top, spacing: .small) {
            stagedThumbnail(candidate)

            VStack(alignment: .leading, spacing: .xxxSmall) {
                Text(candidate.credit.isEmpty ? "No credit in the manifest" : candidate.credit)
                    .font(.caption)
                    .foregroundStyle(candidate.credit.isEmpty ? .red : .primary)

                if !candidate.place.isEmpty || !candidate.observedOn.isEmpty {
                    Text([candidate.place, candidate.observedOn].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("\(candidate.agreeingIdentifications) agreeing ID(s) · \(candidate.licence.uppercased()) · \(candidate.bytes / 1024) KB")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let sourceURL = candidate.sourceURL {
                    Link("Observation", destination: sourceURL)
                        .font(.caption2)
                }
            }

            Spacer()

            VStack(spacing: .xxSmall) {
                Button("Keep") { keep(candidate) }
                    .help("Copy into Photos/ and attach it — the caption is still yours to write")
                    .disabled(photoDirectory == nil)

                Button("Discard", role: .destructive) { discard(candidate) }
                    .help("Delete the staged file. The fetcher can download it again.")
            }
        }
        .padding(.all, .small)
        .background(.quaternary.opacity(Layout.cardBackgroundOpacity), in: EditorLayout.insetShape)
    }

    @ViewBuilder
    private func stagedThumbnail(_ candidate: StagedPhoto) -> some View {
        if let image = NSImage(contentsOf: candidate.fileURL) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: EditorLayout.thumbnailSize, height: EditorLayout.thumbnailSize)
                .clipShape(EditorLayout.insetShape)
        } else {
            EditorLayout.insetShape
                .fill(.quaternary)
                .frame(width: EditorLayout.thumbnailSize, height: EditorLayout.thumbnailSize)
                .allowsHitTesting(false)
        }
    }

    private var fetchHelp: String {
        "Ask iNaturalist for more NZ, research-grade, CC0/CC-BY candidates — "
        + "\(PhotoFetcher.reviewSlack) beyond the \(wantedPhotoCount) this entry wants, so there is "
        + "something to reject. Reads the saved catalogue, so save first if you have just kept or "
        + "removed photos."
    }

    /// Runs the staging fetcher for this entry and drops whatever it finds into the tray.
    private func fetchMore() {
        guard let catalogueURL, let stagingDirectory else { return }
        isFetching = true
        fetchReport = nil

        Task {
            defer { isFetching = false }
            do {
                let outcome = try await PhotoFetcher.topUp(
                    speciesId: species.id,
                    target: wantedPhotoCount,
                    catalogueURL: catalogueURL,
                    stagingDirectory: stagingDirectory
                )
                fetchReport = outcome.message
                reloadStaged()
            } catch {
                fetchReport = nil
                importError = (error as? PhotoFetcher.Failure)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }

    private func reloadStaged() {
        guard let stagingDirectory else {
            staged = []
            return
        }
        staged = StagedPhotos.candidates(forSpecies: species.id, in: stagingDirectory)
    }

    /// Attaches a candidate with its licence attribution and a blank caption, then drops it
    /// from staging so the same frame cannot be attached twice.
    private func keep(_ candidate: StagedPhoto) {
        guard let photoDirectory else { return }
        do {
            let photo = try PhotoImporter.attachEncoded(
                from: candidate.fileURL,
                speciesId: species.id,
                existing: species.photos,
                into: photoDirectory,
                credit: candidate.credit,
                sourceURL: candidate.sourceURL
            )
            onChange(species.with(photos: species.photos + [photo]))
            try StagedPhotos.discard(candidate)
            importError = nil
        } catch {
            importError = (error as? PhotoImporter.Failure)?.errorDescription
                ?? error.localizedDescription
        }
        reloadStaged()
    }

    private func discard(_ candidate: StagedPhoto) {
        do {
            try StagedPhotos.discard(candidate)
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
        reloadStaged()
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
