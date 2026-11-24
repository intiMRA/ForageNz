import Dependencies
import Foundation
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

    /// An oak with two root partners: death cap, shipped, and porcini, still a draft.
    private static func oakAndPartners() -> [ForageSpecies] {
        func fungus(_ id: String, _ name: String, caution: CautionLevel, draft: Bool) -> ForageSpecies {
            ForageSpecies(
                id: id, commonName: name, scientificName: "Fungus \(id)",
                group: .fungi, origin: .introduced, caution: caution,
                summary: "A fungus.", habitat: "Under oak.", identification: "Gills.",
                edibleParts: "Cap.", preparation: "Fry.",
                associations: [Association(kind: .mycorrhizalPartner, entry: .englishOak, note: "Under oak.")],
                photos: [SpeciesPhoto(fileName: "\(id)-1.heic", caption: "Cap.", credit: "(c) Someone (CC BY)")],
                draft: draft
            )
        }
        return [
            ForageSpecies(
                id: "english-oak", commonName: "English oak", scientificName: "Quercus robur",
                group: .nuts, origin: .introduced, caution: .careRequired,
                summary: "Acorns.", habitat: "Parks.", identification: "Lobed leaves.",
                edibleParts: "Acorns.", preparation: "Leach.",
                associations: [
                    Association(kind: .mycorrhizalPartner, entry: .deathCap, note: "Fruits under oak."),
                    Association(kind: .mycorrhizalPartner, entry: .porcini, note: "Fruits under oak.")
                ]
            ),
            fungus("death-cap", "Death cap", caution: .doNotEat, draft: false),
            fungus("porcini", "Porcini", caution: .careRequired, draft: true)
        ]
    }

    @Test("A partner card takes its name, photo and caution from the partner's own entry")
    func associationCardModel() async {
        let store = makeStore(repository: StubRepository(species: Self.oakAndPartners()))
        await store.loadIfNeeded()
        let factory = CatalogueSpeciesModelFactory(store: store)

        let cards = factory.createInfoPageModel(id: .englishOak)?.associationCards
        let card = cards?.first
        #expect(card?.destination == .deathCap)
        #expect(card?.accessibilityIdentifier == "association.death-cap")
        #expect(card?.name == "Death cap")
        #expect(card?.scientificName == "Fungus death-cap")
        #expect(card?.photoFileName == "death-cap-1.heic")
        #expect(card?.note == "Fruits under oak.")
        // The poisonous partner carries its badge, so the danger shows without opening it.
        #expect(card?.caution == .doNotEat)

        // Porcini is a draft, so it has no page to open and no card.
        #expect(cards?.count == 1)
        #expect(factory.createInfoPageModel(id: .deathCap)?.associationCards.map(\.destination) == [.englishOak])
    }

    @Test("The Grows With strip stops at ten cards and offers the rest in a list")
    func associationStripLimit() throws {
        let species = try #require(Self.oakAndPartners().first)
        func page(partners: Int) -> InfoPageModel {
            let cards = SpeciesID.allCases.prefix(partners).map {
                AssociationCardModel(
                    destination: $0, kind: .mycorrhizalPartner, name: $0.rawValue, scientificName: nil,
                    photoFileName: nil, note: "Note.", caution: .careRequired
                )
            }
            return InfoPageModel(species: species, lookalikeCards: [], associationCards: Array(cards))
        }

        #expect(page(partners: 10).associationStripCards.count == 10)
        #expect(!page(partners: 10).hasMoreAssociations)

        let eleven = page(partners: 11)
        #expect(eleven.associationStripCards.map(\.destination) == Array(SpeciesID.allCases.prefix(10)))
        #expect(eleven.hasMoreAssociations)
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

    @Test("A find's pin carries its species' name and group")
    func findPin() async {
        let factory = await Self.factory()
        let find = FindSnapshot(
            id: UUID(), speciesIDRaw: "wild-fennel",
            coordinate: Coordinate(latitude: -41, longitude: 174), foundAt: .now
        )

        let pin = factory.createFindPinModel(find)

        #expect(pin.id == find.id)
        #expect(pin.coordinate == find.coordinate)
        #expect(pin.speciesID == .wildFennel)
        #expect(pin.commonName == "Wild fennel")
        #expect(pin.group == .herbs)
    }

    @Test("A find whose species the guide lacks keeps its pin but opens nothing", arguments: ["gone-plant", "kawakawa"])
    func findPinWithoutSpecies(speciesIDRaw: String) async {
        let factory = await Self.factory()
        let find = FindSnapshot(
            id: UUID(), speciesIDRaw: speciesIDRaw,
            coordinate: Coordinate(latitude: -41, longitude: 174), foundAt: .now
        )

        let pin = factory.createFindPinModel(find)

        #expect(pin.coordinate == find.coordinate)
        #expect(pin.speciesID == nil)
        #expect(pin.commonName == nil)
        #expect(pin.group == nil)
    }
}
