import AppKit
import ForageCatalogue
import SwiftUI

struct CatalogueEditorApp: App {
    @State private var store = CatalogueStore(fileURL: CatalogueLocator.resolve())
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            EditorRootView(store: store)
                .frame(minWidth: 900, minHeight: 600)
                .task { store.load() }
        }
        .commands {
            CommandGroup(after: .saveItem) {
                Button("Save Catalogue") { store.save() }
                    .keyboardShortcut("s")
                    .disabled(!store.hasUnsavedChanges)
            }
        }
    }
}

/// Launched from `swift run`, the process is an unbundled executable, so it needs to ask
/// for a Dock presence and focus itself or the window opens behind the terminal.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }
}

/// Finds `species.json` by walking up from the executable towards the repo root, so the
/// editor works from `swift run` without arguments. `--catalogue <path>` overrides it.
enum CatalogueLocator {
    static let relativePath = "ForageNZ/Catalogue/species.json"

    static func resolve(
        arguments: [String] = CommandLine.arguments,
        currentDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> URL {
        if let flag = arguments.firstIndex(of: "--catalogue"), arguments.count > flag + 1 {
            return URL(fileURLWithPath: arguments[flag + 1])
        }
        return search(from: currentDirectory) ?? currentDirectory.appending(path: relativePath)
    }

    /// Walks up at most 6 levels looking for the catalogue.
    static func search(from start: URL) -> URL? {
        var directory = start
        for _ in 0..<6 {
            let candidate = directory.appending(path: relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { break }
            directory = parent
        }
        return nil
    }
}
