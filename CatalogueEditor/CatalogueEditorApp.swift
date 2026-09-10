import ForageCatalogue
import SwiftUI

@main
struct CatalogueEditorApp: App {
    @State private var store = CatalogueStore(fileURL: CatalogueLocator.resolve())

    var body: some Scene {
        WindowGroup {
            EditorRootView(store: store)
                .frame(minWidth: EditorLayout.windowMinimum.width, minHeight: EditorLayout.windowMinimum.height)
                .task { store.load() }
        }
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save Catalogue") { store.save() }
                    .keyboardShortcut("s")
                    .disabled(!store.hasUnsavedChanges)
            }
        }
    }
}
