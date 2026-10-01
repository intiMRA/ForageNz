import Foundation
import Testing

import ForageCatalogue

@Suite("Book source")
struct BookSourceTests {
    @Test("The flag and its note survive a JSON round trip")
    func roundTrip() throws {
        let species = makeSpecies(needsBookSource: true, sourcingNote: "Knox, A Forager's Treasury.")
        let data = try JSONEncoder().encode(species)
        let decoded = try JSONDecoder().decode(ForageSpecies.self, from: data)
        #expect(decoded.needsBookSource)
        #expect(decoded.sourcingNote == "Knox, A Forager's Treasury.")
    }

    /// The keys are new, so every entry written before they existed still has to decode — the
    /// same treatment `draft` and `habitats` get. `false` here means nobody has searched, not
    /// that a search came back clean.
    @Test("An entry with neither key decodes as not-yet-searched, not as a failure")
    func missingKeysDecode() throws {
        let json = """
        {
          "id": "test", "commonName": "Test", "scientificName": "Testus",
          "group": "greens", "origin": "introduced", "caution": "straightforward",
          "months": [], "summary": {"text": "s", "sources": []},
          "habitat": {"text": "h", "sources": []},
          "identification": {"text": "i", "sources": []},
          "edibleParts": {"text": "e", "sources": []},
          "preparation": {"text": "p", "sources": []},
          "lookalikes": [], "warnings": [], "sources": [], "recipes": [], "photos": []
        }
        """
        let decoded = try JSONDecoder().decode(ForageSpecies.self, from: Data(json.utf8))
        #expect(!decoded.needsBookSource)
        #expect(decoded.sourcingNote == nil)
    }

    @Test("Waiting on a book is an advisory, never a reason to fail the build")
    func flaggedIsAdvisoryOnly() {
        let waiting = makeSpecies(needsBookSource: true, sourcingNote: "Knox, A Forager's Treasury.")
        let issue = waiting.validationIssues.first { $0.field == .needsBookSource }
        #expect(issue?.severity == .advisory)
        #expect(waiting.isPublishable)

        let unflagged = makeSpecies(needsBookSource: false, sourcingNote: nil)
        #expect(!unflagged.validationIssues.contains { $0.field == .needsBookSource })
    }

    @Test("The note is quoted in the advisory, so the editor says which book")
    func advisoryQuotesTheNote() {
        let waiting = makeSpecies(needsBookSource: true, sourcingNote: "Knox, A Forager's Treasury.")
        let issue = waiting.validationIssues.first { $0.field == .needsBookSource }
        #expect(issue?.message.contains("Knox, A Forager's Treasury.") == true)
    }

    /// A flag with no note leaves the next person exactly where an untagged entry does, which
    /// is the state this field exists to prevent.
    @Test("Flagged with no note is called out, and a blank note counts as none")
    func flaggedWithoutNote() {
        for note in [nil, "", "   "] as [String?] {
            let waiting = makeSpecies(needsBookSource: true, sourcingNote: note)
            let issue = waiting.validationIssues.first { $0.field == .needsBookSource }
            #expect(issue?.severity == .advisory)
            #expect(issue?.message.contains("no note") == true)
        }
    }

    @Test("with(needsBookSource:) and with(sourcingNote:) replace only their own field")
    func withBookSource() {
        let species = makeSpecies(needsBookSource: false, sourcingNote: nil)

        let flagged = species.with(needsBookSource: true)
        #expect(flagged.needsBookSource)
        #expect(flagged.sourcingNote == nil)
        #expect(flagged.commonName == species.commonName)

        let noted = flagged.with(sourcingNote: "Langlands, Foraging New Zealand.")
        #expect(noted.needsBookSource)
        #expect(noted.sourcingNote == "Langlands, Foraging New Zealand.")

        // The double optional has to be able to clear the note, not only set it.
        #expect(noted.with(sourcingNote: .some(nil)).sourcingNote == nil)
        #expect(species.with(commonName: "Other").needsBookSource == false)
    }

    private func makeSpecies(needsBookSource: Bool, sourcingNote: String?) -> ForageSpecies {
        ForageSpecies(
            id: "test",
            commonName: "Test plant",
            scientificName: "Testus planta",
            group: .greens,
            origin: .introduced,
            caution: .straightforward,
            summary: "A plant for testing.",
            habitat: "Test ground.",
            identification: "Looks like a test.",
            edibleParts: "Leaves.",
            preparation: "Boil.",
            sources: ["Knox, A Forager's Treasury (Allen & Unwin, 2013)."],
            needsBookSource: needsBookSource,
            sourcingNote: sourcingNote
        )
    }
}
