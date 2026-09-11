import Foundation

enum Logging {
    /// One subsystem for every logger in the app, so Console filters find them all.
    static let subsystem = Bundle.main.bundleIdentifier ?? "nz.co.intialbuquerque.ForageNZ"
}
