import SwiftUI

extension View {
    /// Hosts the one editor for creating and editing lists, driven by
    /// `ListsStore.editorRequest`. Installed once, on the root view.
    func listEditor() -> some View {
        modifier(ListEditorHost())
    }
}

private struct ListEditorHost: ViewModifier {
    @Environment(ListsStore.self) private var lists

    func body(content: Content) -> some View {
        @Bindable var lists = lists
        content
            .sheet(item: $lists.editorRequest) { request in
                ListEditor(request: request, editing: editedList(request))
            }
            .alert(
                "Couldn’t update your lists",
                isPresented: Binding(
                    get: { lists.errorMessage != nil },
                    set: { if !$0 { lists.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(lists.errorMessage ?? "")
            }
    }

    private func editedList(_ request: ListsStore.EditorRequest) -> SpeciesListSnapshot? {
        guard case .edit(let id) = request else { return nil }
        return lists.list(id: id)
    }
}

private struct ListEditor: View {
    let request: ListsStore.EditorRequest

    @Environment(ListsStore.self) private var lists
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var symbolName: String?

    init(request: ListsStore.EditorRequest, editing list: SpeciesListSnapshot?) {
        self.request = request
        _name = State(initialValue: list?.name ?? "")
        _symbolName = State(initialValue: list?.symbolName)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("listName")

                Section {
                    NavigationLink {
                        ListSymbolPicker(selection: $symbolName)
                    } label: {
                        LabeledContent("Icon") {
                            if let symbolName {
                                Image(systemName: symbolName)
                            } else {
                                Text("None")
                            }
                        }
                    }
                    .accessibilityIdentifier("chooseListIcon")

                    if symbolName != nil {
                        Button("Remove icon", role: .destructive) {
                            symbolName = nil
                        }
                        .accessibilityIdentifier("removeListIcon")
                    }
                } footer: {
                    Text("Optional. Shown next to the list’s name.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("saveList")
                }
            }
        }
    }

    private var title: LocalizedStringKey {
        if case .edit = request { "Edit list" } else { "New list" }
    }

    private func save() {
        let (entered, symbol) = (name, symbolName)
        dismiss()
        Task {
            switch request {
            case .create(let species):
                await lists.createList(named: entered, symbolName: symbol, adding: species)
            case .edit(let id):
                await lists.updateList(id, name: entered, symbolName: symbol)
            }
        }
    }
}
