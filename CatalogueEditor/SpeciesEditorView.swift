import ForageCatalogue
import SwiftUI

/// The editable sheet for one species. Everything visible here is an input; derived facts
/// live in the sidebar and toolbar instead.
struct SpeciesEditorView: View {
    let species: ForageSpecies
    let onChange: (ForageSpecies) -> Void

    @State private var showingIssues = false

    var body: some View {
        Form {
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
                LabelledField(
                    "Habitat",
                    text: binding(\.habitat) { $0.with(habitat: $1) },
                    lines: 3...8
                )
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

            Section("Sources") {
                StringListEditor(
                    values: species.sources,
                    addLabel: "Add source",
                    placeholder: "Langlands, Foraging New Zealand (2024), p. 112",
                    lines: 1...3
                ) { onChange(species.with(sources: $0)) }
            }

            Section("Recipes") {
                RecipeEditor(recipes: species.recipes) { onChange(species.with(recipes: $0)) }
            }

            if !species.validationIssues.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showingIssues) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(species.validationIssues) { issue in
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
                        .padding(.top, 4)
                    } label: {
                        issueSummary
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(species.commonName.isEmpty ? "Untitled species" : species.commonName)
        .navigationSubtitle(species.id)
    }

    private var issueSummary: some View {
        let blocking = species.blockingIssues.count
        let advisory = species.validationIssues.count - blocking
        return HStack(spacing: 6) {
            if blocking > 0 {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                Text("\(blocking) still to fill in")
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Nothing blocking")
            }
            if advisory > 0 {
                Text("· \(advisory) suggested")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
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

/// A labelled text input. Uses `TextField(axis: .vertical)` rather than `TextEditor` —
/// it sizes to its content in a Form and needs no decorative overlay, which is what
/// previously sat on top of these fields and swallowed every click.
private struct LabelledField: View {
    let label: String
    @Binding var text: String
    var italic = false
    var lines: ClosedRange<Int>?
    var help: String?

    init(
        _ label: String,
        text: Binding<String>,
        italic: Bool = false,
        lines: ClosedRange<Int>? = nil,
        help: String? = nil
    ) {
        self.label = label
        self._text = text
        self.italic = italic
        self.lines = lines
        self.help = help
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Group {
                if let lines {
                    TextField(label, text: $text, axis: .vertical)
                        .lineLimit(lines)
                } else {
                    TextField(label, text: $text)
                }
            }
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .italic(italic)

            if let help {
                Text(help)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct StringListEditor: View {
    let values: [String]
    let addLabel: String
    let placeholder: String
    let lines: ClosedRange<Int>
    let onChange: ([String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if values.isEmpty {
                Text("None yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                HStack(alignment: .top, spacing: 6) {
                    TextField(placeholder, text: Binding(
                        get: { value },
                        set: { newValue in
                            var next = values
                            next[index] = newValue
                            onChange(next)
                        }
                    ), axis: .vertical)
                    .lineLimit(lines)
                    .textFieldStyle(.roundedBorder)

                    Button {
                        var next = values
                        next.remove(at: index)
                        onChange(next)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove")
                }
            }

            Button(addLabel, systemImage: "plus.circle") { onChange(values + [""]) }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}

private struct RecipeEditor: View {
    let recipes: [Recipe]
    let onChange: ([Recipe]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if recipes.isEmpty {
                Text("None yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(recipes.enumerated()), id: \.offset) { index, recipe in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        TextField("Title", text: Binding(
                            get: { recipe.title },
                            set: { replace(index, Recipe(title: $0, method: recipe.method)) }
                        ))
                        .textFieldStyle(.roundedBorder)

                        Button {
                            var next = recipes
                            next.remove(at: index)
                            onChange(next)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove recipe")
                    }

                    TextField("Method", text: Binding(
                        get: { recipe.method },
                        set: { replace(index, Recipe(title: recipe.title, method: $0)) }
                    ), axis: .vertical)
                    .lineLimit(2...8)
                    .textFieldStyle(.roundedBorder)
                }
            }

            Button("Add recipe", systemImage: "plus.circle") {
                onChange(recipes + [Recipe(title: "", method: "")])
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
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
            if lookalikes.isEmpty {
                Text("None recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(lookalikes.enumerated()), id: \.offset) { index, lookalike in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        TextField("Name", text: Binding(
                            get: { lookalike.name },
                            set: { replace(index, lookalike, name: $0) }
                        ))
                        .textFieldStyle(.roundedBorder)

                        Picker("Risk", selection: Binding(
                            get: { lookalike.risk },
                            set: { replace(index, lookalike, risk: $0) }
                        )) {
                            Text("Deadly").tag(LookalikeRisk.deadly)
                            Text("Toxic").tag(LookalikeRisk.toxic)
                            Text("Unpalatable").tag(LookalikeRisk.unpalatable)
                        }
                        .labelsHidden()
                        .frame(width: 140)

                        Button {
                            var next = lookalikes
                            next.remove(at: index)
                            onChange(next)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove lookalike")
                    }

                    TextField("Scientific name", text: Binding(
                        get: { lookalike.scientificName ?? "" },
                        set: { replace(index, lookalike, scientificName: $0.isEmpty ? nil : $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .italic()

                    TextField("How to tell them apart", text: Binding(
                        get: { lookalike.howToTell },
                        set: { replace(index, lookalike, howToTell: $0) }
                    ), axis: .vertical)
                    .lineLimit(2...8)
                    .textFieldStyle(.roundedBorder)
                }
                .padding(10)
                .background(
                    (lookalike.risk == .deadly ? Color.red : Color.secondary).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6)
                )
            }

            Button("Add lookalike", systemImage: "plus.circle") {
                onChange(lookalikes + [Lookalike(name: "", risk: .toxic, howToTell: "")])
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
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
        HStack(spacing: 4) {
            ForEach(ForageMonth.allCases, id: \.rawValue) { month in
                let isOn = months.contains(month)
                Button(month.shortName) {
                    onChange(isOn ? months.filter { $0 != month } : (months + [month]).sorted())
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .frame(minWidth: 26)
                .padding(.vertical, 5)
                .background(
                    isOn ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 4)
                )
            }
        }
        .padding(.vertical, 2)
    }
}
