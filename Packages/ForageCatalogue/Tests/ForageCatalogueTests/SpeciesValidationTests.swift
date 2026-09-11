import Foundation
import Testing

import ForageCatalogue

@Suite("Species validation")
struct SpeciesValidationTests {
    private func makeSpecies(
        id: String = "test",
        commonName: String = "Test",
        scientificName: String = "Testus testa",
        origin: ForageOrigin = .introduced,
        caution: CautionLevel = .straightforward,
        summary: String = "A summary.",
        habitat: String = "Somewhere.",
        identification: String = "Distinctive.",
        edibleParts: String = "Leaves.",
        preparation: String = "Boil.",
        lookalikes: [Lookalike] = [],
        warnings: [String] = [],
        harvestEthics: String? = nil,
        sources: [String] = ["A Book, p. 1"],
        recipes: [Recipe] = []
    ) -> ForageSpecies {
        ForageSpecies(
            id: id, commonName: commonName, scientificName: scientificName,
            category: .greens, origin: origin, caution: caution,
            summary: summary, habitat: habitat, identification: identification,
            edibleParts: edibleParts, preparation: preparation,
            lookalikes: lookalikes, warnings: warnings, harvestEthics: harvestEthics,
            sources: sources, recipes: recipes
        )
    }

    private func fields(_ species: ForageSpecies, severity: ValidationIssue.Severity) -> Set<ValidationField> {
        Set(species.validationIssues.filter { $0.severity == severity }.map(\.field))
    }

    /// `photos[2]`-style labels, for rules that point at one element of a list.
    private func labels(_ species: ForageSpecies, severity: ValidationIssue.Severity) -> Set<String> {
        Set(species.validationIssues.filter { $0.severity == severity }.map(\.label))
    }

    @Test("A complete entry has nothing blocking")
    func completeEntryPasses() {
        let species = makeSpecies()
        #expect(species.isPublishable)
        #expect(species.blockingIssues.isEmpty)
    }

    @Test("Missing prose the app renders is blocking")
    func missingProseBlocks() {
        let species = makeSpecies(scientificName: "", summary: "  ", habitat: "", identification: "")
        let blocking = fields(species, severity: .blocking)
        #expect(blocking.isSuperset(of: [.scientificName, .summary, .habitat, .identification]))
        #expect(!species.isPublishable)
    }

    @Test("A lookalike with no distinguishing check is blocking")
    func lookalikeNeedsHowToTell() {
        let species = makeSpecies(
            caution: .careRequired,
            lookalikes: [Lookalike(name: "Hemlock", risk: .deadly, howToTell: "   ", entry: .hemlock)]
        )
        #expect(labels(species, severity: .blocking).contains("lookalikes[0]"))
    }

    @Test("A species cannot name itself as a lookalike")
    func selfLookalikeBlocks() {
        let selfie = Lookalike(name: "Itself", risk: .toxic, howToTell: "Look harder.", entry: .hemlock)
        let species = makeSpecies(id: "hemlock", caution: .careRequired, lookalikes: [selfie])
        #expect(labels(species, severity: .blocking).contains("lookalikes[0]"))
        #expect(makeSpecies(id: "wild-fennel", caution: .careRequired, lookalikes: [selfie]).isPublishable)
    }

    @Test("Identifiers cannot start with a digit — they become enum cases")
    func identifierNoLeadingDigit() {
        #expect(fields(makeSpecies(id: "2-leaf"), severity: .blocking).contains(.id))
    }

    @Test("A deadly lookalike cannot sit on a straightforward entry")
    func deadlyLookalikeRaisesCaution() {
        let deadly = Lookalike(name: "Hemlock", risk: .deadly, howToTell: "Purple-blotched stem.", entry: .hemlock)
        #expect(fields(makeSpecies(caution: .straightforward, lookalikes: [deadly]), severity: .blocking).contains(.caution))
        #expect(makeSpecies(caution: .careRequired, lookalikes: [deadly]).isPublishable)
    }

    @Test("A do-not-eat entry must claim no edible parts and say why")
    func doNotEatRules() {
        let claimsFood = makeSpecies(caution: .doNotEat, edibleParts: "Berries.", warnings: ["Lethal."])
        #expect(fields(claimsFood, severity: .blocking).contains(.edibleParts))

        let silent = makeSpecies(caution: .doNotEat, edibleParts: "None.", warnings: [])
        #expect(fields(silent, severity: .blocking).contains(.warnings))

        #expect(makeSpecies(caution: .doNotEat, edibleParts: "None.", warnings: ["Lethal."]).isPublishable)
    }

    @Test("A care-required entry must say why care is needed")
    func careRequiredNeedsAReason() {
        #expect(fields(makeSpecies(caution: .careRequired), severity: .blocking).contains(.warnings))
        #expect(makeSpecies(caution: .careRequired, warnings: ["Cook it."]).isPublishable)
    }

    @Test("Native and endemic species need harvesting guidance", arguments: [ForageOrigin.native, .endemic])
    func indigenousNeedsEthics(origin: ForageOrigin) {
        #expect(fields(makeSpecies(origin: origin), severity: .blocking).contains(.harvestEthics))
        #expect(makeSpecies(origin: origin, harvestEthics: "Take sparingly.").isPublishable)
    }

    @Test("Introduced species and weeds are not held to tikanga guidance", arguments: [ForageOrigin.introduced, .pest])
    func nonIndigenousNeedsNoEthics(origin: ForageOrigin) {
        #expect(!fields(makeSpecies(origin: origin), severity: .blocking).contains(.harvestEthics))
    }

    @Test("No sources is advisory, a blank source is blocking")
    func sourceRules() {
        #expect(fields(makeSpecies(sources: []), severity: .advisory).contains(.sources))
        #expect(makeSpecies(sources: []).isPublishable)
        #expect(fields(makeSpecies(sources: ["A Book", " "]), severity: .blocking).contains(.sources))
    }

    @Test("A recipe without a title is blocking")
    func recipeNeedsTitle() {
        let species = makeSpecies(recipes: [Recipe(title: "", method: "Boil.")])
        #expect(labels(species, severity: .blocking).contains("recipes[0]"))
    }

    @Test("Identifiers must be slug-shaped")
    func identifierShape() {
        #expect(fields(makeSpecies(id: "Wild Fennel"), severity: .blocking).contains(.id))
        #expect(fields(makeSpecies(id: ""), severity: .blocking).contains(.id))
        #expect(makeSpecies(id: "wild-fennel-2").isPublishable)
    }

    @Test("Identifiers derive predictably from a common name")
    func identifierDerivation() {
        // Macrons fold to their base vowel rather than being dropped.
        #expect(ForageSpecies.makeIdentifier(from: "Pūhā / Sow thistle") == "puha-sow-thistle")
        #expect(ForageSpecies.makeIdentifier(from: "Kōwhitiwhiti") == "kowhitiwhiti")
        #expect(ForageSpecies.makeIdentifier(from: "  Wild Fennel  ") == "wild-fennel")
        #expect(ForageSpecies.makeIdentifier(from: "Saffron Milk Cap") == "saffron-milk-cap")
        #expect(ForageSpecies.makeIdentifier(from: "!!!") == "")
    }
}
