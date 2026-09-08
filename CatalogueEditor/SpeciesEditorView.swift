import ForageCatalogue
import SwiftUI

/// The editable sheet for one species.
struct SpeciesEditorView: View {
    let species: ForageSpecies
    let onChange: (ForageSpecies) -> Void

    var body: some View {
        Form {
            if !species.validationIssues.isEmpty {
                Section {
                    ForEach(species.validationIssues) { issue in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(issue.message)
                                Text(issue.field)
                                    .font(.caption)
                                    .monospaced()
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: issue.severity == .blocking
                                ? "exclamationmark.octagon.fill"
                                : "info.circle")
                                .foregroundStyle(issue.severity == .blocking ? .red : .secondary)
                        }
                    }
                } header: {
                    Text(species.isPublishable ? "Worth finishing" : "Still to fill in")
                } footer: {
                    if !species.isPublishable {
                        Text("Red items fail the app's build, so the entry can't ship until they're resolved.")
                            .font(.caption)
                    }
                }
            }

            Section {
                LabeledContent("Verification") {
                    if species.isVerified {
                        Label("\(species.sources.count) source(s) recorded", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not yet checked against a book", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                LabeledContent("Priority", value: species.reviewTierLabel)
                LabeledContent("Identifier", value: species.id)
                    .monospaced()
            }

            Section("Sources — book and page") {
                StringListEditor(
                    values: species.sources,
                    addLabel: "Add source",
                    placeholder: "Langlands, Foraging New Zealand (2024), p. 112",
                    onChange: { onChange(species.with(sources: $0)) }
                )
            }

            Section("Names") {
                TextField("Common name", text: binding(\.commonName) { $0.with(commonName: $1) })
                TextField("Te reo Māori name", text: optionalBinding(\.maoriName) { $0.with(maoriName: $1) })
                TextField("Scientific name", text: binding(\.scientificName) { $0.with(scientificName: $1) })
                    .italic()
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

            Section("Season") {
                MonthPicker(
                    months: species.months,
                    onChange: { onChange(species.with(months: $0)) }
                )
                Text(species.seasonDescription)
                    .foregroundStyle(.secondary)
            }

            Section("Description") {
                LabeledTextEditor("Summary", text: binding(\.summary) { $0.with(summary: $1) })
                LabeledTextEditor("Habitat", text: binding(\.habitat) { $0.with(habitat: $1) })
                LabeledTextEditor("Identification", text: binding(\.identification) { $0.with(identification: $1) })
            }

            if species.caution != .doNotEat {
                Section("Use") {
                    LabeledTextEditor("Edible parts", text: binding(\.edibleParts) { $0.with(edibleParts: $1) })
                    LabeledTextEditor("Preparation", text: binding(\.preparation) { $0.with(preparation: $1) })
                }
            }

            Section("Lookalikes — the field-critical checks") {
                LookalikeEditor(
                    lookalikes: species.lookalikes,
                    onChange: { onChange(species.with(lookalikes: $0)) }
                )
            }

            Section("Warnings") {
                StringListEditor(
                    values: species.warnings,
                    addLabel: "Add warning",
                    placeholder: "What will hurt someone, and how",
                    onChange: { onChange(species.with(warnings: $0)) }
                )
            }

            Section("Harvesting & tikanga") {
                LabeledTextEditor(
                    "Guidance",
                    text: optionalBinding(\.harvestEthics) { $0.with(harvestEthics: $1) }
                )
            }

            Section("Recipes") {
                RecipeEditor(
                    recipes: species.recipes,
                    onChange: { onChange(species.with(recipes: $0)) }
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(species.commonName)
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

/// A multi-line field with a label above it — `TextField(axis:)` collapses too readily
/// for paragraph-length identification notes.
private struct LabeledTextEditor: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 66)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(.quaternary))
        }
    }
}

private struct StringListEditor: View {
    let values: [String]
    let addLabel: String
    let placeholder: String
    let onChange: ([String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                HStack(alignment: .top) {
                    TextField(placeholder, text: Binding(
                        get: { value },
                        set: { newValue in
                            var next = values
                            next[index] = newValue
                            onChange(next)
                        }
                    ), axis: .vertical)
                    Button {
                        var next = values
                        next.remove(at: index)
                        onChange(next)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove")
                }
            }
            Button(addLabel, systemImage: "plus") { onChange(values + [""]) }
                .buttonStyle(.borderless)
        }
    }
}

private struct RecipeEditor: View {
    let recipes: [Recipe]
    let onChange: ([Recipe]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(recipes.enumerated()), id: \.offset) { index, recipe in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("Title", text: Binding(
                            get: { recipe.title },
                            set: { replace(index, Recipe(title: $0, method: recipe.method)) }
                        ))
                        Button {
                            var next = recipes
                            next.remove(at: index)
                            onChange(next)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove recipe")
                    }
                    TextField("Method", text: Binding(
                        get: { recipe.method },
                        set: { replace(index, Recipe(title: recipe.title, method: $0)) }
                    ), axis: .vertical)
                    .lineLimit(2...6)
                }
                .padding(8)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }
            Button("Add recipe", systemImage: "plus") {
                onChange(recipes + [Recipe(title: "", method: "")])
            }
            .buttonStyle(.borderless)
        }
    }

    private func replace(_ index: Int, _ recipe: Recipe) {
        var next = recipes
        next[index] = recipe
        onChange(next)
    }
}

private struct LookalikeEditor: View {
    let lookalikes: [Lookalike]
    let onChange: ([Lookalike]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(lookalikes.enumerated()), id: \.offset) { index, lookalike in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("Name", text: binding(index, lookalike, \.name))
                        Picker("", selection: Binding(
                            get: { lookalike.risk },
                            set: { replace(index, lookalike, risk: $0) }
                        )) {
                            Text("Deadly").tag(LookalikeRisk.deadly)
                            Text("Toxic").tag(LookalikeRisk.toxic)
                            Text("Unpalatable").tag(LookalikeRisk.unpalatable)
                        }
                        .labelsHidden()
                        .frame(width: 130)
                        Button {
                            var next = lookalikes
                            next.remove(at: index)
                            onChange(next)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove lookalike")
                    }
                    TextField("Scientific name", text: Binding(
                        get: { lookalike.scientificName ?? "" },
                        set: { replace(index, lookalike, scientificName: $0.isEmpty ? nil : $0) }
                    ))
                    .italic()
                    Text("How to tell them apart — be specific and field-checkable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("How to tell", text: binding(index, lookalike, \.howToTell), axis: .vertical)
                        .lineLimit(2...8)
                }
                .padding(8)
                .background(
                    (lookalike.risk == .deadly ? Color.red : Color.secondary).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6)
                )
            }
            Button("Add lookalike", systemImage: "plus") {
                onChange(lookalikes + [Lookalike(name: "", risk: .toxic, howToTell: "")])
            }
            .buttonStyle(.borderless)
        }
    }

    private func binding(
        _ index: Int,
        _ lookalike: Lookalike,
        _ keyPath: KeyPath<Lookalike, String>
    ) -> Binding<String> {
        Binding(
            get: { lookalike[keyPath: keyPath] },
            set: { newValue in
                if keyPath == \Lookalike.name {
                    replace(index, lookalike, name: newValue)
                } else {
                    replace(index, lookalike, howToTell: newValue)
                }
            }
        )
    }

    private func replace(
        _ index: Int,
        _ lookalike: Lookalike,
        name: String? = nil,
        scientificName: String?? = nil,
        risk: LookalikeRisk? = nil,
        howToTell: String? = nil
    ) {
        var next = lookalikes
        next[index] = Lookalike(
            name: name ?? lookalike.name,
            scientificName: scientificName ?? lookalike.scientificName,
            risk: risk ?? lookalike.risk,
            howToTell: howToTell ?? lookalike.howToTell
        )
        onChange(next)
    }
}

private struct MonthPicker: View {
    let months: [ForageMonth]
    let onChange: ([ForageMonth]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Leave every month off for a year-round species.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(ForageMonth.allCases, id: \.rawValue) { month in
                    let isOn = months.contains(month)
                    Button(month.shortName) {
                        onChange(isOn
                            ? months.filter { $0 != month }
                            : (months + [month]).sorted())
                    }
                    .buttonStyle(.borderless)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(
                        isOn ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
                }
            }
        }
    }
}
