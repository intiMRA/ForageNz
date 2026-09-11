import Foundation

public nonisolated struct Recipe: Codable, Sendable, Hashable {
    public let title: String
    /// Method and quantities, in prose. Kept deliberately unstructured — a foraging
    /// recipe is usually "boil it and change the water", not a measured formula.
    public let method: String

    public init(title: String, method: String) {
        self.title = title
        self.method = method
    }
}
