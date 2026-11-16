import DesignLibrary
import SwiftUI

/// The bookmark on a species card: every list with a tick where the species is in it, and
/// "New list…". Filled when the species is in any list.
struct AddToListMenu: View {
    let speciesID: SpeciesID
    var hasCircleBackground = true

    @Environment(ListsStore.self) private var lists

    var body: some View {
        Menu {
            ForEach(lists.lists) { list in
                Button {
                    Task { await lists.toggle(speciesID, inList: list.id) }
                } label: {
                    if list.contains(speciesID) {
                        Label(list.name, systemImage: "checkmark")
                    } else {
                        ListLabel(list: list)
                    }
                }
            }

            Divider()

            Button {
                lists.editorRequest = .create(adding: speciesID)
            } label: {
                Label("New list…", systemImage: "plus")
            }
        } label: {
            Image(lists.isListed(speciesID) ? .listAdded : .listAdd)
                .icon(size: .standard, color: .primary)
                .if(hasCircleBackground, transform: { view in
                    view
                        .foregroundStyle(.tint)
                        .padding(.all, .xxxSmall)
                        .conditionalGlass(in: Circle(), isInteractive: true)
                })
                
        }
        .accessibilityLabel("Add to list")
        .accessibilityValue(lists.isListed(speciesID) ? "In a list" : "")
        .accessibilityIdentifier("addToList.\(speciesID.rawValue)")
    }
}
