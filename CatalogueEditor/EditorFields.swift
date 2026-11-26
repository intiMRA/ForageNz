import DesignLibrary
import SwiftUI

/// A labelled text input. Uses `TextField(axis: .vertical)` rather than `TextEditor` —
/// it sizes to its content in a Form and needs no decorative overlay, which is what
/// previously sat on top of these fields and swallowed every click.
struct LabelledField: View {
    let label: String
    @Binding var text: String
    let italic: Bool
    let lines: ClosedRange<Int>?
    let help: String?

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
        VStack(alignment: .leading, spacing: .xxSmall) {
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
        .padding(.vertical, .xxxSmall)
    }
}

struct StringListEditor: View {
    let values: [String]
    let addLabel: String
    let placeholder: String
    let lines: ClosedRange<Int>
    let onChange: ([String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .xSmall) {
            if values.isEmpty {
                Text("None yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                HStack(alignment: .top, spacing: .xSmall) {
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
        .padding(.vertical, .xxxSmall)
    }
}

struct RecipeEditor: View {
    let recipes: [Recipe]
    let onChange: ([Recipe]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .small) {
            if recipes.isEmpty {
                Text("None yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(recipes.enumerated()), id: \.offset) { index, recipe in
                VStack(alignment: .leading, spacing: .xSmall) {
                    HStack(spacing: .xSmall) {
                        TextField("Title", text: Binding(
                            get: { recipe.title },
                            set: { replace(index, Recipe(title: $0, method: recipe.method, sourceURL: recipe.sourceURL)) }
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
                        set: { replace(index, Recipe(title: recipe.title, method: $0, sourceURL: recipe.sourceURL)) }
                    ), axis: .vertical)
                    .lineLimit(2...8)
                    .textFieldStyle(.roundedBorder)

                    TextField("Source link", text: Binding(
                        get: { recipe.sourceURL?.absoluteString ?? "" },
                        set: { replace(index, Recipe(title: recipe.title, method: recipe.method, sourceURL: URL(string: $0.trimmingCharacters(in: .whitespaces)))) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }

            Button("Add recipe", systemImage: "plus.circle") {
                onChange(recipes + [Recipe(title: "", method: "")])
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, .xxxSmall)
    }

    private func replace(_ index: Int, _ recipe: Recipe) {
        var next = recipes
        next[index] = recipe
        onChange(next)
    }
}

struct LookalikeEditor: View {
    @Environment(\.colorScheme) private var colorScheme

    let lookalikes: [Lookalike]
    /// The species being edited. A new card starts by pointing at it, which validation flags
    /// as blocking — so an untouched card can never quietly ship pointing somewhere plausible.
    let owner: SpeciesID?
    let onChange: ([Lookalike]) -> Void

    /// Pulled out of the row's `.background(_:in:)` because inlining the ternary made the row
    /// body too much for the type checker.
    private func banner(for risk: LookalikeRisk) -> AnyShapeStyle {
        let style = risk == .deadly
            ? risk.tintColor.style(.card, in: colorScheme)
            : AnyShapeStyle(Color.secondary)
        return AnyShapeStyle(style.opacity(Layout.bannerBackgroundOpacity))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .small) {
            if lookalikes.isEmpty {
                Text("None recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(lookalikes.enumerated()), id: \.offset) { index, lookalike in
                VStack(alignment: .leading, spacing: .xSmall) {
                    HStack(spacing: .xSmall) {
                        TextField("Name", text: Binding(
                            get: { lookalike.name },
                            set: { replace(index, lookalike, name: $0) }
                        ))
                        .textFieldStyle(.roundedBorder)

                        Picker("Risk", selection: Binding(
                            get: { lookalike.risk },
                            set: { replace(index, lookalike, risk: $0) }
                        )) {
                            ForEach(LookalikeRisk.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: EditorLayout.riskPickerWidth)

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

                    Picker("Opens page", selection: Binding(
                        get: { lookalike.entry },
                        set: { replace(index, lookalike, entry: $0) }
                    )) {
                        ForEach(SpeciesID.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                .padding(.all, .small)
                // A deadly lookalike is a caution affordance, so its tint comes from the one
                // semantic mapping — not a system red that happens to look similar.
                .background(banner(for: lookalike.risk), in: EditorLayout.insetShape)
            }

            Button("Add lookalike", systemImage: "plus.circle") {
                onChange(lookalikes + [
                    Lookalike(name: "", risk: .toxic, howToTell: "", entry: defaultEntry)
                ])
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, .xxxSmall)
    }

    private var defaultEntry: SpeciesID {
        owner ?? SpeciesID.allCases[0]
    }

    private func replace(
        _ index: Int,
        _ lookalike: Lookalike,
        name: String? = nil,
        scientificName: String?? = nil,
        risk: LookalikeRisk? = nil,
        howToTell: String? = nil,
        entry: SpeciesID? = nil
    ) {
        var next = lookalikes
        next[index] = Lookalike(
            name: name ?? lookalike.name,
            scientificName: scientificName ?? lookalike.scientificName,
            risk: risk ?? lookalike.risk,
            howToTell: howToTell ?? lookalike.howToTell,
            entry: entry ?? lookalike.entry
        )
        onChange(next)
    }
}

struct AssociationEditor: View {
    let associations: [Association]
    /// The species being edited. A new link starts by pointing at it, which validation flags
    /// as blocking, for the same reason as a new lookalike card.
    let owner: SpeciesID?
    let onChange: ([Association]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .small) {
            if associations.isEmpty {
                Text("None recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(associations.enumerated()), id: \.offset) { index, association in
                VStack(alignment: .leading, spacing: .xSmall) {
                    HStack(spacing: .xSmall) {
                        Picker("Kind", selection: Binding(
                            get: { association.kind },
                            set: { replace(index, association, kind: $0) }
                        )) {
                            ForEach(AssociationKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }

                        Button {
                            var next = associations
                            next.remove(at: index)
                            onChange(next)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove partner")
                    }

                    Picker("Partner page", selection: Binding(
                        get: { association.entry },
                        set: { replace(index, association, entry: $0) }
                    )) {
                        ForEach(SpeciesID.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }

                    TextField("Note for the card", text: Binding(
                        get: { association.note },
                        set: { replace(index, association, note: $0) }
                    ), axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                }
                .padding(.all, .small)
                .background(Color.secondary.opacity(Layout.bannerBackgroundOpacity), in: EditorLayout.insetShape)
            }

            Button("Add partner", systemImage: "plus.circle") {
                onChange(associations + [
                    Association(kind: .mycorrhizalPartner, entry: owner ?? SpeciesID.allCases[0], note: "")
                ])
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, .xxxSmall)
    }

    private func replace(
        _ index: Int,
        _ association: Association,
        kind: AssociationKind? = nil,
        entry: SpeciesID? = nil,
        note: String? = nil
    ) {
        var next = associations
        next[index] = Association(
            kind: kind ?? association.kind,
            entry: entry ?? association.entry,
            note: note ?? association.note
        )
        onChange(next)
    }
}

/// The structured companion to the habitat text field. Toggles rather than a single
/// selection, because a species that grows on roadsides and riverbanks grows in both.
struct HabitatPicker: View {
    let habitats: [Habitat]
    let onChange: ([Habitat]) -> Void

    /// `LazyVGrid` and `GridItem` have no `CommonPadding` overload, so the token is unwrapped
    /// here rather than a loose number being written in.
    private static let gap = CommonPadding.xxSmall.rawValue

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: EditorLayout.habitatButtonMinimumWidth), spacing: Self.gap)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Self.gap) {
            ForEach(Habitat.allCases) { habitat in
                let isOn = habitats.contains(habitat)
                Button {
                    // Rebuilt in `allCases` order, so the saved file does not record the
                    // order someone happened to click in.
                    let next = isOn ? habitats.filter { $0 != habitat } : habitats + [habitat]
                    onChange(Habitat.allCases.filter(next.contains))
                } label: {
                    Label {
                        Text(habitat.shortLabel)
                    } icon: {
                        habitat.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: Layout.chipIconSize, height: Layout.chipIconSize)
                    }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .padding(.horizontal, .xxSmall)
                .padding(.vertical, .xxSmall)
                .background(
                    isOn
                        ? Color.accentColor.opacity(EditorLayout.selectedTintOpacity)
                        : Color.secondary.opacity(Layout.bannerBackgroundOpacity),
                    in: EditorLayout.insetShape
                )
                .help(habitat.displayName)
            }
        }
        .padding(.vertical, .xxxSmall)
    }
}

struct MonthPicker: View {
    let months: [ForageMonth]
    let onChange: ([ForageMonth]) -> Void

    var body: some View {
        HStack(spacing: .xxSmall) {
            ForEach(ForageMonth.allCases, id: \.rawValue) { month in
                let isOn = months.contains(month)
                Button(month.shortName) {
                    onChange(isOn ? months.filter { $0 != month } : (months + [month]).sorted())
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .frame(minWidth: EditorLayout.monthButtonMinimumWidth)
                .padding(.vertical, .xxSmall)
                .background(
                    isOn
                        ? Color.accentColor.opacity(EditorLayout.selectedTintOpacity)
                        : Color.secondary.opacity(Layout.bannerBackgroundOpacity),
                    in: EditorLayout.insetShape
                )
            }
        }
        .padding(.vertical, .xxxSmall)
    }
}

/// The non-food uses on an entry (`docs/plans/useful-plants.md`). Each use carries its own
/// sources beside its part and method, because a use has no "written for this guide" case:
/// rewriting the text clears them (`SourcedText.with(text:)`), and validation then asks for
/// them back.
struct UseEditor: View {
    let uses: [SpeciesUse]
    let onChange: ([SpeciesUse]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .small) {
            if uses.isEmpty {
                Text("None recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(uses.enumerated()), id: \.offset) { index, use in
                VStack(alignment: .leading, spacing: .xSmall) {
                    HStack(spacing: .xSmall) {
                        Picker("Kind", selection: Binding(
                            get: { use.kind },
                            set: { replace(index, use, kind: $0) }
                        )) {
                            ForEach(UseKind.allCases) { Text($0.displayName).tag($0) }
                        }

                        Button {
                            var next = uses
                            next.remove(at: index)
                            onChange(next)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove use")
                    }

                    LabelledField("Part used", text: Binding(
                        get: { use.parts.text },
                        set: { replace(index, use, parts: use.parts.with(text: $0)) }
                    ), lines: 1...4)
                    sourceList(use.parts.sources) { replace(index, use, parts: SourcedText(use.parts.text, sources: $0)) }

                    LabeledContent("Harvest window") {
                        MonthPicker(months: use.months) { replace(index, use, months: $0) }
                    }

                    LabelledField("How it is processed", text: Binding(
                        get: { use.method.text },
                        set: { replace(index, use, method: use.method.with(text: $0)) }
                    ), lines: 2...8)
                    sourceList(use.method.sources) { replace(index, use, method: SourcedText(use.method.text, sources: $0)) }

                    Text("Handling warnings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StringListEditor(
                        values: use.warnings,
                        addLabel: "Add warning",
                        placeholder: "Sap, fumes, lye, mordants — what will hurt someone",
                        lines: 1...4
                    ) { replace(index, use, warnings: $0) }

                    Text("Recipes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    RecipeEditor(recipes: use.recipes) { replace(index, use, recipes: $0) }
                }
                .padding(.all, .small)
                .background(Color.secondary.opacity(Layout.bannerBackgroundOpacity), in: EditorLayout.insetShape)
            }

            Button("Add use", systemImage: "plus.circle") {
                onChange(uses + [SpeciesUse(kind: .fibre, parts: "", method: "")])
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, .xxxSmall)
    }

    private func sourceList(_ sources: [String], onChange: @escaping ([String]) -> Void) -> some View {
        StringListEditor(
            values: sources,
            addLabel: "Add source",
            placeholder: "Ngā Rauropi Whakaoranga, 'Phormium tenax' (URL, retrieved date)",
            lines: 1...3,
            onChange: onChange
        )
    }

    private func replace(
        _ index: Int,
        _ use: SpeciesUse,
        kind: UseKind? = nil,
        parts: SourcedText? = nil,
        months: [ForageMonth]? = nil,
        method: SourcedText? = nil,
        warnings: [String]? = nil,
        recipes: [Recipe]? = nil
    ) {
        var next = uses
        next[index] = SpeciesUse(
            kind: kind ?? use.kind,
            parts: parts ?? use.parts,
            months: months ?? use.months,
            method: method ?? use.method,
            warnings: warnings ?? use.warnings,
            recipes: recipes ?? use.recipes
        )
        onChange(next)
    }
}
