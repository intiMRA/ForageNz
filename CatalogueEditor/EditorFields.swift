import ForageCatalogue
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

struct StringListEditor: View {
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

struct RecipeEditor: View {
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

struct LookalikeEditor: View {
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
                }
                .padding(10)
                // A deadly lookalike is a caution affordance, so its tint comes from the one
                // semantic mapping — not a system red that happens to look similar.
                .background(
                    (lookalike.risk == .deadly ? lookalike.risk.tintColor : Color.secondary)
                        .opacity(Layout.bannerBackgroundOpacity),
                    in: EditorLayout.insetShape
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

struct MonthPicker: View {
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
                .frame(minWidth: EditorLayout.monthButtonMinimumWidth)
                .padding(.vertical, 5)
                .background(
                    isOn
                        ? Color.accentColor.opacity(EditorLayout.selectedTintOpacity)
                        : Color.secondary.opacity(Layout.bannerBackgroundOpacity),
                    in: EditorLayout.insetShape
                )
            }
        }
        .padding(.vertical, 2)
    }
}
