import Foundation

/// A paragraph and where it came from.
///
/// Every prose field on a species is one of these, so a screen can put the credit under
/// the exact text it applies to. `sources` holds short credits such as
/// "Wikipedia, 'Agaricus arvensis' (CC BY-SA 4.0)"; empty means the text was written for
/// this guide. The full citations live in `ForageSpecies.sources`.
public nonisolated struct SourcedText: Codable, Sendable, Hashable, ExpressibleByStringLiteral {
    public let text: String
    public let sources: [String]

    public init(_ text: String, sources: [String] = []) {
        self.text = text
        self.sources = sources
    }

    /// Literals are hand-written text with no source, which is what tests and the editor's
    /// "new species" template mean by a plain string.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        sources = try container.decodeIfPresent([String].self, forKey: .sources) ?? []
    }

    /// The credit does not survive a rewrite: once the words are yours, crediting someone
    /// else for them is a false claim, and this is the call the editor makes on every
    /// keystroke. Re-state the sources deliberately if the text is still theirs.
    public func with(text: String) -> SourcedText {
        text == self.text ? self : SourcedText(text)
    }

    public var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
