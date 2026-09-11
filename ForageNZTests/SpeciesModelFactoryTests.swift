import ForageCatalogue
import Testing

@testable import ForageNZ

private struct StubRepository: SpeciesRepository {
    let species: [ForageSpecies]
    func loadSpecies() async throws(SpeciesRepositoryError) -> [ForageSpecies] { species }
}

/// Models are plain values, so the factory is tested without rendering a single view.
@Suite("Species model factory")
@MainActor
struct SpeciesModelFactoryTests {
    private static func fennelAndHemlock() -> [ForageSpecies] {
        let hemlockCard = Lookalike(
            name: "Hemlock", scientificName: "Conium maculatum", risk: .deadly,
            howToTell: "Blotched stem, musty smell.", entry: .hemlock
        )
        return [
            ForageSpecies(
                id: "wild-fennel", commonName: "Wild fennel", scientificName: "Foeniculum vulgare",
                category: .herbs, origin: .pest, caution: .careRequired, months: [.january, .february],
                summary: "Aniseed.", habitat: "Verges.", identification: "Feathery.",
                edibleParts: "Fronds.", preparation: "Raw.", lookalikes: [hemlockCard]
            ),
            ForageSpecies(
                id: "hemlock", commonName: "Hemlock", scientificName: "Conium maculatum",
                category: .herbs, origin: .pest, caution: .doNotEat,
                summary: "Lethal.", habitat: "Verges.", identification: "Blotched.",
                edibleParts: ForageSpecies.noEdibleParts, preparation: "None.", warnings: ["Lethal."]
            )
        ]
    }

    private static func factory() async -> CatalogueSpeciesModelFactory {
        let store = SpeciesStore(repository: StubRepository(species: fennelAndHemlock()))
        await store.loadIfNeeded()
        return CatalogueSpeciesModelFactory(store: store)
    }

    @Test("A row model carries what the row shows, and flags a deadly lookalike only on edibles")
    func rowModel() async {
        let factory = await Self.factory()

        let fennel = factory.createListingRowModel(id: .wildFennel)
        #expect(fennel?.commonName == "Wild fennel")
        #expect(fennel?.seasonDescription == "Jan – Feb")
        #expect(fennel?.hasDeadlyLookalike == true)

        // Hemlock is the danger itself; the "deadly lookalike" badge is for the edible it threatens.
        #expect(factory.createListingRowModel(id: .hemlock)?.hasDeadlyLookalike == false)
    }

    @Test("A lookalike card's destination is the SpeciesID the catalogue named")
    func lookalikeCardModel() async {
        let factory = await Self.factory()
        let page = factory.createInfoPageModel(id: .wildFennel)

        let card = page?.lookalikeCards.first
        #expect(card?.destination == .hemlock)
        #expect(card?.accessibilityIdentifier == "lookalike.hemlock")
        #expect(card?.risk == .deadly)
        #expect(card?.howToTell == "Blotched stem, musty smell.")
    }

    @Test("The info page model resolves every lookalike to a card")
    func infoPageModel() async {
        let factory = await Self.factory()
        #expect(factory.createInfoPageModel(id: .wildFennel)?.lookalikeCards.count == 1)
        #expect(factory.createInfoPageModel(id: .hemlock)?.lookalikeCards.isEmpty == true)
    }

    @Test("An id the loaded catalogue lacks yields no model rather than a guess")
    func missingSpecies() async {
        let factory = await Self.factory()
        #expect(factory.createInfoPageModel(id: .deathCap) == nil)
        #expect(factory.createListingRowModel(id: .deathCap) == nil)
    }

    @Test("Without an injected factory the default produces nothing to render")
    func unconfiguredDefault() {
        let factory = UnconfiguredSpeciesModelFactory()
        #expect(factory.createInfoPageModel(id: .hemlock) == nil)
        #expect(factory.createListingRowModel(id: .hemlock) == nil)
    }
}
