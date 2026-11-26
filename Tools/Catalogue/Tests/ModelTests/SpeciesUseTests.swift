import Foundation
import Testing

import ForageCatalogue

@Suite("Non-food uses")
struct SpeciesUseTests {
    private let recipeURL = URL(string: "https://example.org/recipe")

    private func makeUse(
        kind: UseKind = .dye,
        parts: SourcedText = SourcedText("Flower heads.", sources: ["A dye book, p. 4"]),
        method: SourcedText = SourcedText("Simmer with alum-mordanted wool.", sources: ["A dye book, p. 4"]),
        warnings: [String] = [],
        recipes: [Recipe] = []
    ) -> SpeciesUse {
        SpeciesUse(kind: kind, parts: parts, method: method, warnings: warnings, recipes: recipes)
    }

    private func makeSpecies(
        caution: CautionLevel = .careRequired,
        harvestEthics: SourcedText? = nil,
        uses: [SpeciesUse]
    ) -> ForageSpecies {
        ForageSpecies(
            id: "test", commonName: "Test", scientificName: "Testus testa",
            group: .greens, origin: .introduced, caution: caution,
            summary: "A summary.", habitat: "Somewhere.", habitats: [.forest], identification: "Distinctive.",
            edibleParts: caution.isHarvestable ? "Leaves." : "None.", preparation: "Boil.",
            warnings: ["Sap stings."], harvestEthics: harvestEthics, sources: ["A Book, p. 1"],
            uses: uses,
            photos: [SpeciesPhoto(fileName: "test-1.heic", caption: "Whole plant.", credit: "Someone (CC BY 4.0)")]
        )
    }

    private func useMessages(_ species: ForageSpecies) -> [String] {
        species.blockingIssues.filter { $0.field == .uses }.map(\.message)
    }

    @Test("A sourced use passes, on an edible entry and on a do-not-eat one")
    func sourcedUsePasses() {
        #expect(makeSpecies(uses: [makeUse()]).isPublishable)
        #expect(makeSpecies(caution: .doNotEat, uses: [makeUse()]).isPublishable)
    }

    @Test("A use without its part, method or sources blocks")
    func incompleteUseBlocks() {
        #expect(!useMessages(makeSpecies(uses: [makeUse(parts: "")])).isEmpty)
        #expect(!useMessages(makeSpecies(uses: [makeUse(method: "  ")])).isEmpty)
        #expect(!useMessages(makeSpecies(uses: [makeUse(parts: "Flower heads.")])).isEmpty)
        #expect(!useMessages(makeSpecies(uses: [makeUse(method: "Simmer.")])).isEmpty)
    }

    @Test("The issue points at the use it belongs to")
    func issuePointsAtTheUse() {
        let species = makeSpecies(uses: [makeUse(), makeUse(kind: .fibre, parts: "")])
        #expect(species.blockingIssues.map(\.label).contains("uses[1]"))
        #expect(!species.blockingIssues.map(\.label).contains("uses[0]"))
    }

    @Test("Lye or a toxic mordant needs a warning")
    func harshChemicalsNeedAWarning() {
        let lye = SourcedText("Cold-process soap with lye.", sources: ["Soap page"])
        #expect(!useMessages(makeSpecies(uses: [makeUse(kind: .skinCare, method: lye)])).isEmpty)
        #expect(useMessages(makeSpecies(uses: [makeUse(kind: .skinCare, method: lye, warnings: ["Lye burns skin and eyes."])])).isEmpty)

        let chromeRecipe = Recipe(title: "Gold wool", method: "Mordant with potassium dichromate.", sourceURL: recipeURL)
        #expect(!useMessages(makeSpecies(uses: [makeUse(recipes: [chromeRecipe])])).isEmpty)
    }

    @Test("Alum, iron pots and tins do not count as harsh chemicals")
    func everydayMordantsPass() {
        let method = SourcedText("Mordant with alum, simmer in an iron pot, store in a tin.", sources: ["A dye book"])
        #expect(useMessages(makeSpecies(uses: [makeUse(method: method)])).isEmpty)
    }

    @Test("A medical claim on any use blocks, and 'treat' only on skin care")
    func skinCareIsCosmeticOnly() {
        let healing = Recipe(title: "Healing balm", method: "Infuse the flowers in oil.", sourceURL: recipeURL)
        #expect(!useMessages(makeSpecies(uses: [makeUse(kind: .skinCare, recipes: [healing])])).isEmpty)

        let balm = Recipe(title: "Flower balm", method: "Infuse the flowers in oil.", sourceURL: recipeURL)
        #expect(useMessages(makeSpecies(uses: [makeUse(kind: .skinCare, recipes: [balm])])).isEmpty)

        let treated = SourcedText("Treat the wool with alum first.", sources: ["A dye book"])
        #expect(useMessages(makeSpecies(uses: [makeUse(method: treated)])).isEmpty)

        let firstAid = SourcedText("Glue the bearing block; keep some in your first aid kit for splinters.", sources: ["A bushcraft page"])
        #expect(!useMessages(makeSpecies(uses: [makeUse(kind: .craft, method: firstAid)])).isEmpty)
    }

    @Test("Skin care on a plant nobody may eat needs a warning")
    func skinCareOnDoNotEatNeedsAWarning() {
        #expect(!useMessages(makeSpecies(caution: .doNotEat, uses: [makeUse(kind: .skinCare)])).isEmpty)
        let warned = makeUse(kind: .skinCare, warnings: ["The sap can blister skin."])
        #expect(useMessages(makeSpecies(caution: .doNotEat, uses: [warned])).isEmpty)
    }

    @Test("Use recipes need a link, and none on an at-risk species")
    func useRecipesFollowTheFoodRules() {
        let unlinked = Recipe(title: "Dye bath", method: "Simmer.")
        #expect(!useMessages(makeSpecies(uses: [makeUse(recipes: [unlinked])])).isEmpty)

        let linked = Recipe(title: "Dye bath", method: "Simmer.", sourceURL: recipeURL)
        let atRisk = makeSpecies(harvestEthics: "This species is at risk. If you harvest it, take only a little.", uses: [makeUse(recipes: [linked])])
        #expect(!useMessages(atRisk).isEmpty)
    }

    @Test("Attributing a claim in a use's prose blocks")
    func attributionBlocks() {
        let method = SourcedText("One forager says to simmer it.", sources: ["A blog"])
        #expect(!useMessages(makeSpecies(uses: [makeUse(method: method)])).isEmpty)
    }

    @Test("A use missing its optional keys still decodes")
    func optionalKeysDecode() throws {
        let json = #"{"kind":"fibre","parts":{"text":"Leaves."},"method":{"text":"Strip and dry."}}"#
        let use = try JSONDecoder().decode(SpeciesUse.self, from: Data(json.utf8))
        #expect(use.months.isEmpty && use.warnings.isEmpty && use.recipes.isEmpty)
    }
}
