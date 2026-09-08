import ForageCatalogue
import SwiftUI

/// One entry, split across tabs.
///
/// A single scrolling form buried the photo importer ten sections down. Tabs keep every
/// part one click away, and each tab carries its own blocking-issue count so it's obvious
/// where the gaps are without opening them.
struct SpeciesEditorView: View {
    let species: ForageSpecies
    let photoDirectory: URL?
    let onChange: (ForageSpecies) -> Void

    @State private var tab: EditorTab = .entry

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(EditorTab.allCases) { candidate in
                    Text(label(for: candidate)).tag(candidate)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            Form {
                switch tab {
                case .entry: entryTab
                case .photos: photosTab
                case .safety: safetyTab
                case .provenance: provenanceTab
                }

                let issues = species.validationIssues.filter { tab.owns(field: $0.field) }
                if !issues.isEmpty {
                    Section("Still to fill in here") {
                        ForEach(issues) { issue in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: issue.severity == .blocking
                                    ? "exclamationmark.circle.fill" : "info.circle")
                                    .foregroundStyle(issue.severity == .blocking ? .red : .secondary)
                                Text(issue.message)
                                Spacer(minLength: 0)
                                Text(issue.field)
                                    .font(.caption)
                                    .monospaced()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .navigationTitle(species.commonName.isEmpty ? "Untitled species" : species.commonName)
        .navigationSubtitle(species.id)
    }

    private func label(for tab: EditorTab) -> String {
        let blocking = species.blockingIssues.filter { tab.owns(field: $0.field) }.count
        return blocking == 0 ? tab.title : "\(tab.title) (\(blocking))"
    }

    // MARK: - Tabs

    @ViewBuilder
    private var entryTab: some View {
        Section("Names") {
            LabelledField("Common name", text: binding(\.commonName) { $0.with(commonName: $1) })
            LabelledField("Te reo Māori name", text: optionalBinding(\.maoriName) { $0.with(maoriName: $1) })
            LabelledField(
                "Scientific name",
                text: binding(\.scientificName) { $0.with(scientificName: $1) },
                italic: true
            )
        }

        Section("Classification") {
            Picker("Category", selection: binding(\.category) { $0.with(category: $1) }) {
                ForEach(ForageCategory.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Origin", selection: binding(\.origin) { $0.with(origin: $1) }) {
                ForEach(ForageOrigin.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Caution", selection: binding(\.caution) { $0.with(caution: $1) }) {
                Text("Straightforward").tag(CautionLevel.straightforward)
                Text("Care required").tag(CautionLevel.careRequired)
                Text("Do not eat").tag(CautionLevel.doNotEat)
            }
        }

        Section {
            MonthPicker(months: species.months) { onChange(species.with(months: $0)) }
        } header: {
            Text("Season")
        } footer: {
            Text("Shows in the app as “\(species.seasonDescription)”. Leave every month off for year-round.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Description") {
            LabelledField(
                "Summary",
                text: binding(\.summary) { $0.with(summary: $1) },
                lines: 2...4,
                help: "One line. It's the subtitle in every list."
            )
            LabelledField("Habitat", text: binding(\.habitat) { $0.with(habitat: $1) }, lines: 3...8)
            LabelledField(
                "Identification",
                text: binding(\.identification) { $0.with(identification: $1) },
                lines: 4...12,
                help: "What to check in the field."
            )
        }

        Section("Use") {
            LabelledField(
                "Edible parts",
                text: binding(\.edibleParts) { $0.with(edibleParts: $1) },
                lines: 2...6,
                help: species.caution == .doNotEat ? "Must say “none” for a do-not-eat entry." : nil
            )
            LabelledField(
                "Preparation",
                text: binding(\.preparation) { $0.with(preparation: $1) },
                lines: 3...8
            )
        }
    }

    @ViewBuilder
    private var photosTab: some View {
        Section {
            PhotoSectionView(species: species, photoDirectory: photoDirectory, onChange: onChange)
        } footer: {
            Text("Photos ship inside the app: each stays under \(CataloguePhotos.maximumBytesPerPhoto / 1024) KB, and the whole catalogue under \(CataloguePhotos.totalByteBudget / 1_000_000) MB. Imports are downscaled and re-encoded automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var safetyTab: some View {
        Section {
            LookalikeEditor(lookalikes: species.lookalikes) { onChange(species.with(lookalikes: $0)) }
        } header: {
            Text("Lookalikes")
        } footer: {
            Text("The field-critical part. Give a difference someone can check while holding the plant.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Warnings") {
            StringListEditor(
                values: species.warnings,
                addLabel: "Add warning",
                placeholder: "What will hurt someone, and how",
                lines: 2...6
            ) { onChange(species.with(warnings: $0)) }
        }

        Section("Harvesting & tikanga") {
            LabelledField(
                "Guidance",
                text: optionalBinding(\.harvestEthics) { $0.with(harvestEthics: $1) },
                lines: 3...8,
                help: species.origin == .native ? "Required for native species." : nil
            )
        }
    }

    @ViewBuilder
    private var provenanceTab: some View {
        Section {
            StringListEditor(
                values: species.sources,
                addLabel: "Add source",
                placeholder: "Langlands, Foraging New Zealand (2024), p. 112",
                lines: 1...3
            ) { onChange(species.with(sources: $0)) }
        } header: {
            Text("Sources")
        } footer: {
            Text("Book and page. An entry with no source shows a “not yet checked” banner in the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Recipes") {
            RecipeEditor(recipes: species.recipes) { onChange(species.with(recipes: $0)) }
        }
    }

    // MARK: - Bindings

    private func binding<Value>(
        _ keyPath: KeyPath<ForageSpecies, Value>,
        _ apply: @escaping (ForageSpecies, Value) -> ForageSpecies
    ) -> Binding<Value> {
        Binding(
            get: { species[keyPath: keyPath] },
            set: { onChange(apply(species, $0)) }
        )
    }

    private func optionalBinding(
        _ keyPath: KeyPath<ForageSpecies, String?>,
        _ apply: @escaping (ForageSpecies, String?) -> ForageSpecies
    ) -> Binding<String> {
        Binding(
            get: { species[keyPath: keyPath] ?? "" },
            set: { onChange(apply(species, $0.isEmpty ? nil : $0)) }
        )
    }
}

/// Which tab owns a validation field, so each tab can report its own gaps.
enum EditorTab: String, CaseIterable, Identifiable {
    case entry
    case photos
    case safety
    case provenance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .entry: "Entry"
        case .photos: "Photos"
        case .safety: "Safety"
        case .provenance: "Sources"
        }
    }

    func owns(field: String) -> Bool {
        let root = String(field.prefix { $0 != "[" })
        return switch self {
        case .entry:
            ["id", "commonName", "scientificName", "summary", "habitat",
             "identification", "edibleParts", "preparation", "caution", "months"].contains(root)
        case .photos:
            root == "photos"
        case .safety:
            ["lookalikes", "warnings", "harvestEthics"].contains(root)
        case .provenance:
            ["sources", "recipes"].contains(root)
        }
    }
}
