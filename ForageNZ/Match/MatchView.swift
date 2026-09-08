import DesignLibrary
import ForageCatalogue
import PhotosUI
import SwiftUI

/// Ranks a photo against the guide's own photos.
///
/// This is not identification and the screen says so plainly. It narrows 30-odd entries to a
/// few worth reading, and the reading is where identification actually happens.
struct MatchView: View {
    @Environment(SpeciesStore.self) private var store

    @State private var service = PhotoMatchService()
    @State private var selection: PhotosPickerItem?
    @State private var pickedImage: Image?
    @State private var matches: [PhotoMatch] = []
    @State private var coverage: PhotoMatchService.Coverage?
    @State private var isWorking = false
    @State private var failure: String?

    var body: some View {
        List {
            Section {
                disclaimer
            }

            if let coverage, !coverage.isUsable {
                Section {
                    thinCoverageWarning(coverage)
                }
            }

            Section {
                PhotosPicker(selection: $selection, matching: .images) {
                    Label("Choose a photo", systemImage: "photo.badge.plus")
                }

                if let pickedImage {
                    pickedImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: Layout.photoHeight * 1.4)
                        .clipShape(Layout.cardShape)
                        .listRowInsets(EdgeInsets())
                }

                if isWorking {
                    HStack(spacing: .xSmall) {
                        ProgressView()
                        Text("Comparing…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let failure {
                Section {
                    Label(failure, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(.cautionCare))
                }
            }

            if !matches.isEmpty {
                Section {
                    ForEach(matches) { match in
                        if let species = store.species.first(where: { $0.id == match.speciesId }) {
                            NavigationLink(value: species) {
                                MatchRow(species: species, match: match)
                            }
                        }
                    }
                } header: {
                    Text("Worth reading, closest first")
                } footer: {
                    Text("Open each one and work through its lookalike checks. A closer match is not a more likely answer.")
                }
            }
        }
        .navigationTitle("Match a photo")
        .task {
            coverage = await service.coverage(for: store.species)
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task { await run(item) }
        }
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: .xxSmall) {
            Label("This does not identify anything", systemImage: "info.circle.fill")
                .font(.headline)
            Text("It compares your photo to the photos in this guide and shows the closest entries. Visual similarity is not identification — a deadly species can photograph almost identically to an edible one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, .xxSmall)
    }

    private func thinCoverageWarning(_ coverage: PhotoMatchService.Coverage) -> some View {
        VStack(alignment: .leading, spacing: .xxSmall) {
            Label("Not enough photos yet", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(Color(.cautionCare))
            Text("Only \(coverage.speciesWithPhotos) of \(coverage.speciesTotal) entries have photos, so almost anything will “match” one of them. Results here mean nothing until at least \(PhotoMatchService.Coverage.usableMinimum) entries have photos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, .xxSmall)
    }

    private func run(_ item: PhotosPickerItem) async {
        isWorking = true
        failure = nil
        matches = []
        defer { isWorking = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            failure = "That photo couldn't be loaded."
            return
        }
        pickedImage = Image(uiImage: UIImage(data: data) ?? UIImage())

        do {
            matches = try await service.matches(forImageData: data, species: store.species)
        } catch PhotoMatchService.Failure.noPhotosBundled {
            failure = "This build has no catalogue photos to compare against."
        } catch {
            failure = "That photo couldn't be compared."
        }
    }
}

private struct MatchRow: View {
    let species: ForageSpecies
    let match: PhotoMatch

    var body: some View {
        VStack(alignment: .leading, spacing: .xxSmall) {
            SpeciesRow(species: species)

            if match.isAvoidOnly {
                Label("Shown because it must never be eaten", systemImage: "xmark.octagon.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CautionLevel.doNotEat.tintColor)
            }
        }
    }
}
