import Foundation
import Testing

@testable import ForageNZ

@Suite("Links in text")
@MainActor
struct TextLinkTests {
    /// The runs of `text` that carry a link, as (linked text, destination).
    private static func links(in text: AttributedString) -> [(String, URL)] {
        text.runs.compactMap { run in
            run.link.map { (String(text[run.range].characters), $0) }
        }
    }

    @Test("A source line's web address becomes a link, and the words around it do not")
    func linksTheAddressOnly() throws {
        let source = "Flora of New Zealand Online. CC BY 3.0 NZ. https://www.nzflora.info/factsheet/Taxon/Coprosma-robusta.html"
        let links = Self.links(in: AttributedString(linkingWebAddressesIn: source))

        #expect(links.count == 1)
        let (linked, url) = try #require(links.first)
        #expect(linked == "https://www.nzflora.info/factsheet/Taxon/Coprosma-robusta.html")
        #expect(url.absoluteString == linked)
    }

    @Test("Punctuation after an address is not part of the link")
    func trailingPunctuationIsLeftOut() throws {
        let source = "Yates, https://www.yates.co.nz/problem-solver/weeds/oxalis/, retrieved 15/10/2026."
        let (linked, _) = try #require(Self.links(in: AttributedString(linkingWebAddressesIn: source)).first)

        #expect(linked == "https://www.yates.co.nz/problem-solver/weeds/oxalis/")
    }

    @Test("Every address in a line is linked")
    func linksEveryAddress() {
        let source = "Te Aka, https://maoridictionary.co.nz/search?keywords=karamu; NZPCN, https://www.nzpcn.org.nz/flora/species/coprosma-robusta/"

        #expect(Self.links(in: AttributedString(linkingWebAddressesIn: source)).count == 2)
    }

    @Test("A line with no web address, or only an email address, keeps no link and its text")
    func plainLinesStayPlain() {
        for source in ["Langlands, Peter. Foraging New Zealand (2024), 'Karamū' entry.", "Contact author@example.com"] {
            let text = AttributedString(linkingWebAddressesIn: source)
            #expect(Self.links(in: text).isEmpty)
            #expect(String(text.characters) == source)
        }
    }

    @Test("The Poisons Centre number in the safety advice calls the Poisons Centre")
    func poisonsCentreNumberIsTappable() throws {
        let links = Self.links(in: SafetyView.poisoningAdvice)

        #expect(links.count == 1)
        let (linked, url) = try #require(links.first)
        #expect(linked == PoisonsCentre.displayNumber)
        #expect(url == PoisonsCentre.callURL)
    }
}
