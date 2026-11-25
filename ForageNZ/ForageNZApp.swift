import SwiftUI

@main
struct ForageNZApp: App {
    var body: some Scene {
        WindowGroup {
            // Unit tests run inside this app. Left to start, it would load the catalogue and draw
            // the tabs while the tests run, reading live dependencies — the clock — that no test
            // provides. A UI test launches the app as its own process, so it is unaffected.
            if !Self.isHostingUnitTests {
                RootView()
            }
        }
    }

    private static let isHostingUnitTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}
