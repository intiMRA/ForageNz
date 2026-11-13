import SwiftUI

/// The iCloud setting for lists and finds. Off unless the user turns it on; the store is
/// opened at launch, so a change applies the next time the app opens.
struct SyncSettingsView: View {
    @AppStorage(UserDataSettings.syncKey) private var syncsWithICloud = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Sync with iCloud", isOn: $syncsWithICloud)
                        .accessibilityIdentifier("syncWithICloud")
                } footer: {
                    Text("Keeps your lists and finds the same on every device signed in to your iCloud account. Finds include where you found each species, so with sync on those places are stored in your private iCloud account as well as on this device.")
                }

                if syncsWithICloud != UserDataSettings.isSyncEnabledAtLaunch {
                    Section {
                        Text("This takes effect the next time you open ForageNZ.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Lists and finds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// The toolbar button that opens `SyncSettingsView`, shared by the Lists and Map tabs.
struct SyncSettingsButton: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label("iCloud sync", systemImage: "icloud")
        }
        .sheet(isPresented: $isPresented) {
            SyncSettingsView()
        }
    }
}
