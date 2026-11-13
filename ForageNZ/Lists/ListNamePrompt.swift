import SwiftUI

extension View {
    /// Hosts the one name prompt for creating and renaming lists, driven by
    /// `ListsStore.nameRequest`. Installed once, on the root view.
    func listNamePrompt() -> some View {
        modifier(ListNamePrompt())
    }
}

private struct ListNamePrompt: ViewModifier {
    @Environment(ListsStore.self) private var lists

    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: isPresented, presenting: lists.nameRequest) { request in
                TextField("Name", text: $name)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    save(request)
                }
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
            .onChange(of: lists.nameRequest) { _, request in
                guard case .rename(_, let currentName) = request else {
                    name = ""
                    return
                }
                name = currentName
            }
    }

    private var title: LocalizedStringKey {
        if case .rename = lists.nameRequest { "Rename list" } else { "New list" }
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { lists.nameRequest != nil },
            set: { if !$0 { lists.nameRequest = nil } }
        )
    }

    private func save(_ request: ListsStore.NameRequest) {
        let entered = name
        Task {
            switch request {
            case .create(let species):
                await lists.createList(named: entered, adding: species)
            case .rename(let id, _):
                await lists.renameList(id, to: entered)
            }
        }
    }
}
