import Dependencies
import Testing

@testable import ForageNZ

/// Builds the store with a substituted repository.
///
/// `SpeciesStore` reads its collaborators from the dependency context now rather than taking
/// them as initialiser arguments, and `@Dependency` captures that context when the object is
/// created — so construction has to happen *inside* `withDependencies`, not around it.
@MainActor
private func makeStore(repository: any SpeciesRepository) -> SpeciesStore {
    withDependencies { $0.speciesRepository = repository } operation: { SpeciesStore() }
}

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
                group: .herbs, origin: .pest, caution: .careRequired, months: [.january, .february],
                summary: "Aniseed.", habitat: "Verges.", habitats: [.coastal, .disturbed],
                identification: "Feathery.",
                edibleParts: "Fronds.", preparation: "Raw.", lookalikes: [hemlockCard]
            ),
            ForageSpecies(
                id: "hemlock", commonName: "Hemlock", scientificName: "Conium maculatum",
                group: .herbs, origin: .pest, caution: .doNotEat,
                summary: "Lethal.", habitat: "Verges.", identification: "Blotched.",
                edibleParts: SourcedText(ForageSpecies.noEdibleParts), preparation: "None.", warnings: ["Lethal."],
                photos: [SpeciesPhoto(fileName: "hemlock-1.heic", caption: "Blotched stem.", credit: "(c) Someone (CC BY)")]
            )
        ]
    }

    private static func factory() async -> CatalogueSpeciesModelFactory {
        let store = makeStore(repository: StubRepository(species: fennelAndHemlock()))
        await store.loadIfNeeded()
        return CatalogueSpeciesModelFactory(store: store)
    }

    @Test("A row model carries what the row shows")
    func rowModel() async {
        let factory = await Self.factory()

        let fennel = factory.createListingRowModel(id: .wildFennel)
        #expect(fennel?.commonName == "Wild fennel")
        #expect(fennel?.seasonDescription == "Jan – Feb")
        #expect(fennel?.caution == .careRequired)

        // The row draws its own habitat chips, so the classification has to reach the model.
        #expect(fennel?.habitats == [.coastal, .disturbed])
        // An unclassified entry gives the row nothing to draw, rather than an empty chip.
        #expect(factory.createListingRowModel(id: .hemlock)?.habitats.isEmpty == true)

        // The row's thumbnail is the entry's first photo; fennel has none, hemlock does.
        #expect(fennel?.photoFileName == nil)
        #expect(factory.createListingRowModel(id: .hemlock)?.photoFileName == "hemlock-1.heic")
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

        // The card's photo is the destination entry's own first photo. Nothing on the
        // lookalike names a file, so resolving it through the catalogue is the only way the
        // card shows anything but a placeholder.
        #expect(card?.photoFileName == "hemlock-1.heic")
    }

    @Test("A lookalike whose entry has no photo leaves the card to its placeholder")
    func lookalikeCardWithoutPhoto() async {
        let factory = await Self.factory()
        let fennelAsLookalike = Lookalike(
            name: "Wild fennel", risk: .unpalatable, howToTell: "Smells of aniseed.", entry: .wildFennel
        )
        #expect(factory.createLookalikeCardModel(fennelAsLookalike).photoFileName == nil)
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
