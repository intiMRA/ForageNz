import Foundation

public nonisolated struct Recipe: Codable, Sendable, Hashable {
    public let title: String
    /// Method and quantities, in prose. Kept deliberately unstructured — a foraging
    /// recipe is usually "boil it and change the water", not a measured formula.
    public let method: String
    /// The published recipe this one was written from.
    public let sourceURL: URL?

    public init(title: String, method: String, sourceURL: URL? = nil) {
        self.title = title
        self.method = method
        self.sourceURL = sourceURL
    }
}
