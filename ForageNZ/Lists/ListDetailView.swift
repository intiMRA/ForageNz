import DesignLibrary
import SwiftUI

/// One list's species, laid out and filtered like the field guide.
struct ListDetailView: View {
    let listID: SpeciesListSnapshot.ID

    @Environment(ListsStore.self) private var lists
    @Environment(SpeciesStore.self) private var store

    @State private var filter = SpeciesFilter()

    var body: some View {
        if let list = lists.list(id: listID) {
            content(for: list)
        } else {
            ContentUnavailableView("List deleted", systemImage: "bookmark.slash")
        }
    }

    private func content(for list: SpeciesListSnapshot) -> some View {
        let members = store.members(of: list)
        let results = filter.apply(to: members.species)
        return ScrollView {
            LazyVStack {
                OriginGuidance(origin: filter.origin)
                GroupedSpeciesList(species: results)

                if list.speciesIDsRaw.isEmpty {
                    ContentUnavailableView(
                        "Nothing in this list",
                        systemImage: "bookmark",
                        description: Text("Add species with the bookmark on any card in the field guide.")
                    )
                } else if results.isEmpty, !members.species.isEmpty {
                    SpeciesFilterEmptyState(query: filter.query)
                }

                if !members.missingIDsRaw.isEmpty {
                    missingSection(members.missingIDsRaw, in: list)
                }
            }
            .padding(.horizontal, .medium)
        }
        .navigationTitle(list.name)
        .searchable(
            text: $filter.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search this list"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SpeciesFilterMenu(filter: $filter)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    lists.nameRequest = .rename(list.id, currentName: list.name)
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
        }
    }

    /// Entries the guide no longer has. Shown so the user can take them out; never removed
    /// behind their back.
    private func missingSection(_ idsRaw: [String], in list: SpeciesListSnapshot) -> some View {
        VStack(alignment: .leading, spacing: .xSmall) {
            Text("No longer in the guide")
                .bold()
                .font(.headline)
                .padding(.vertical, .xSmall)
            ForEach(idsRaw, id: \.self) { idRaw in
                HStack {
                    Text(idRaw)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Remove", role: .destructive) {
                        Task { await lists.remove(speciesIDRaw: idRaw, fromList: list.id) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
