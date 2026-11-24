import Foundation

public nonisolated struct Recipe: Codable, Sendable, Hashable {
    public let title: String
    
    public let method: String
    
    public let sourceURL: URL?

    public init(title: String, method: String, sourceURL: URL? = nil) {
        self.title = title
        self.method = method
        self.sourceURL = sourceURL
    }
}
