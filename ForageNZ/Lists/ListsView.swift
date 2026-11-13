import SwiftUI

struct ListsView: View {
    @Environment(ListsStore.self) private var lists
    @Environment(\.router) private var router

    var body: some View {
        content
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SyncSettingsButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        lists.nameRequest = .create(adding: nil)
                    } label: {
                        Label("New list", systemImage: "plus")
                    }
                    .accessibilityIdentifier("newList")
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch lists.loadState {
        case .idle, .loading:
            ProgressView()
        case .failed(let message):
            ContentUnavailableView {
                Label("Lists unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    Task { await lists.loadIfNeeded() }
                }
            }
        case .loaded where lists.lists.isEmpty:
            ContentUnavailableView {
                Label("No lists yet", image: "list-add")
            } description: {
                Text("Make a list, then add species to it with the bookmark on any card in the field guide.")
            } actions: {
                Button("New list") {
                    lists.nameRequest = .create(adding: nil)
                }
            }
        case .loaded:
            List {
                ForEach(lists.lists) { list in
                    Button {
                        router.push(.list(list.id))
                    } label: {
                        LabeledContent(list.name) {
                            Text(list.speciesIDsRaw.count, format: .number)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("list.\(list.name)")
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            Task { await lists.deleteList(list.id) }
                        }
                        Button("Rename") {
                            lists.nameRequest = .rename(list.id, currentName: list.name)
                        }
                    }
                }
            }
        }
    }
}
