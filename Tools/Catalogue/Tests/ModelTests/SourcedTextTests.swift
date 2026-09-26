import Foundation
import Testing

import ForageCatalogue

@Suite("SourcedText")
struct SourcedTextTests {
    @Test("Missing sources decode as none, not as a failure")
    func sourcesDefaultToEmpty() throws {
        let decoded = try JSONDecoder().decode(SourcedText.self, from: Data(#"{"text":"x"}"#.utf8))
        #expect(decoded == SourcedText("x"))
        #expect(decoded.sources.isEmpty)
    }

    @Test("Whitespace-only text is blank; a literal carries no source")
    func blankAndLiteral() {
        #expect(SourcedText("  \n").isBlank)
        #expect(!SourcedText("x").isBlank)
        let literal: SourcedText = "Written here."
        #expect(literal.sources.isEmpty)
        // Rewriting the words drops the credit; keeping them keeps it.
        #expect(SourcedText("a", sources: ["s"]).with(text: "b") == SourcedText("b"))
        #expect(SourcedText("a", sources: ["s"]).with(text: "a").sources == ["s"])
    }
}
