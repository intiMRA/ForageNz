import Foundation
import Testing

@testable import ForageNZ

private struct StubRepository: SpeciesRepository {
    let species: [ForageSpecies]
    func loadSpecies() async throws(SpeciesRepositoryError) -> [ForageSpecies] { species }
}

private struct FailingRepository: SpeciesRepository {
    func loadSpecies() async throws(SpeciesRepositoryError) -> [ForageSpecies] {
        throw .catalogueMissing(resourceName: "species")
    }
}

/// Records how many times the store actually reached the repository.
private actor CountingRepository: SpeciesRepository {
    private(set) var loadCallCount = 0
    private let species: [ForageSpecies]

    init(species: [ForageSpecies]) {
        self.species = species
    }

    func loadSpecies() async throws(SpeciesRepositoryError) -> [ForageSpecies] {
        loadCallCount += 1
        return species
    }
}

/// Fails the first call, succeeds thereafter.
private actor FlakyRepository: SpeciesRepository {
    private var hasFailedOnce = false
    private let species: [ForageSpecies]

    init(species: [ForageSpecies]) {
        self.species = species
    }

    func loadSpecies() async throws(SpeciesRepositoryError) -> [ForageSpecies] {
        guard hasFailedOnce else {
            hasFailedOnce = true
            throw .catalogueUnreadable(description: "first attempt")
        }
        return species
    }
}

private func makeSpecies(
    id: String,
    commonName: String = "Plant",
    category: ForageCategory = .greens,
    origin: ForageOrigin = .introduced,
    caution: CautionLevel = .straightforward,
    months: [ForageMonth] = [],
    summary: String = "A plant.",
    lookalikes: [Lookalike] = []
) -> ForageSpecies {
    ForageSpecies(
        id: id,
        commonName: commonName,
        scientificName: "Testus \(id)",
        category: category,
        origin: origin,
        caution: caution,
        months: months,
        summary: summary,
        habitat: "Ground.",
        identification: "Green.",
        edibleParts: "Leaves.",
        preparation: "Boil.",
        lookalikes: lookalikes
    )
}

@Suite("SpeciesStore")
@MainActor
struct SpeciesStoreTests {
    @Test("Loading sorts the catalogue by common name")
    func loadSorts() async {
        let store = SpeciesStore(repository: StubRepository(species: [
            makeSpecies(id: "b", commonName: "Watercress"),
            makeSpecies(id: "a", commonName: "Blackberry")
        ]))

        await store.loadIfNeeded()

        #expect(store.loadState == .loaded)
        #expect(store.species.map(\.commonName) == ["Blackberry", "Watercress"])
    }

    @Test("A missing catalogue surfaces its own message and no species")
    func loadFailure() async {
        let store = SpeciesStore(repository: FailingRepository())

        await store.loadIfNeeded()

        #expect(store.species.isEmpty)
        #expect(
            store.loadState == .failed(
                message: SpeciesRepositoryError.catalogueMissing(resourceName: "species").userMessage
            )
        )
    }

    @Test("An unreadable catalogue surfaces a different message from a missing one")
    func unreadableCatalogueMessage() async {
        let store = SpeciesStore(repository: FlakyRepository(species: []))

        await store.loadIfNeeded()

        let unreadable = SpeciesRepositoryError.catalogueUnreadable(description: "first attempt")
        let missing = SpeciesRepositoryError.catalogueMissing(resourceName: "species")
        #expect(unreadable.userMessage != missing.userMessage)
        #expect(store.loadState == .failed(message: unreadable.userMessage))
    }

    @Test("A second load does not hit the repository again")
    func loadIsIdempotent() async {
        let repository = CountingRepository(species: [makeSpecies(id: "a")])
        let store = SpeciesStore(repository: repository)

        await store.loadIfNeeded()
        await store.loadIfNeeded()
        await store.loadIfNeeded()

        #expect(await repository.loadCallCount == 1)
        #expect(store.species.count == 1)
    }

    @Test("A failed load is retried, and recovers")
    func failedLoadRetries() async {
        let store = SpeciesStore(repository: FlakyRepository(species: [makeSpecies(id: "a")]))

        await store.loadIfNeeded()
        if case .failed = store.loadState {
            // Expected on the first attempt.
        } else {
            Issue.record("Expected the first load to fail, got \(store.loadState)")
        }

        await store.loadIfNeeded()

        #expect(store.loadState == .loaded)
        #expect(store.species.count == 1)
    }

    @Test("In-season excludes do-not-eat entries")
    func inSeasonExcludesToxic() async {
        let store = SpeciesStore(repository: StubRepository(species: [
            makeSpecies(id: "safe", commonName: "Safe", caution: .straightforward, months: [.march]),
            makeSpecies(id: "toxic", commonName: "Toxic", caution: .doNotEat, months: [.march])
        ]))

        await store.loadIfNeeded()

        #expect(store.inSeason(for: .march).map(\.id) == ["safe"])
    }

    @Test("In-season always includes year-round species")
    func inSeasonIncludesYearRound() async {
        let store = SpeciesStore(repository: StubRepository(species: [
            makeSpecies(id: "always", months: []),
            makeSpecies(id: "autumn", months: [.april])
        ]))

        await store.loadIfNeeded()

        #expect(Set(store.inSeason(for: .january).map(\.id)) == ["always"])
        #expect(Set(store.inSeason(for: .april).map(\.id)) == ["always", "autumn"])
    }

    @Test("Deadly-lookalike list omits entries that are themselves inedible")
    func deadlyLookalikesExcludeDoNotEat() async {
        let deadly = Lookalike(name: "Hemlock", risk: .deadly, howToTell: "Purple stem.")
        let store = SpeciesStore(repository: StubRepository(species: [
            makeSpecies(id: "fennel", caution: .careRequired, lookalikes: [deadly]),
            makeSpecies(id: "tutu", caution: .doNotEat, lookalikes: [deadly]),
            makeSpecies(id: "plain", caution: .straightforward)
        ]))

        await store.loadIfNeeded()

        #expect(store.withDeadlyLookalikes.map(\.id) == ["fennel"])
        #expect(store.doNotEat.map(\.id) == ["tutu"])
    }

    @Test("Search matches names and summaries, case-insensitively")
    func search() async {
        let store = SpeciesStore(repository: StubRepository(species: [
            makeSpecies(id: "kawakawa", commonName: "Kawakawa", summary: "Native pepper tree."),
            makeSpecies(id: "puha", commonName: "Pūhā", summary: "Boiled green.")
        ]))

        await store.loadIfNeeded()

        #expect(store.search("KAWA").map(\.id) == ["kawakawa"])
        #expect(store.search("pepper").map(\.id) == ["kawakawa"])
        #expect(store.search("nothing here").isEmpty)
    }

    @Test("Filtering by origin narrows to that origin alone")
    func filterByOrigin() async {
        let store = SpeciesStore(repository: StubRepository(species: [
            makeSpecies(id: "kawakawa", origin: .native),
            makeSpecies(id: "blackberry", origin: .pest),
            makeSpecies(id: "walnut", origin: .introduced)
        ]))

        await store.loadIfNeeded()

        #expect(store.filter(origin: .native).map(\.id) == ["kawakawa"])
        #expect(store.filter(origin: .pest).map(\.id) == ["blackberry"])
        #expect(store.filter(origin: .introduced).map(\.id) == ["walnut"])
    }

    @Test("Category and origin filters compose")
    func filterByCategoryAndOrigin() async {
        let store = SpeciesStore(repository: StubRepository(species: [
            makeSpecies(id: "kawakawa", commonName: "Kawakawa", category: .herbs, origin: .native),
            makeSpecies(id: "horopito", commonName: "Horopito", category: .herbs, origin: .native),
            makeSpecies(id: "fennel", commonName: "Fennel", category: .herbs, origin: .pest),
            makeSpecies(id: "karengo", commonName: "Karengo", category: .seaweed, origin: .native)
        ]))

        await store.loadIfNeeded()

        #expect(store.filter(category: .herbs, origin: .native).map(\.id) == ["horopito", "kawakawa"])
        #expect(store.filter(category: .seaweed, origin: .pest).isEmpty)
    }

    @Test("Filters compose with the search query")
    func filterComposesWithSearch() async {
        let store = SpeciesStore(repository: StubRepository(species: [
            makeSpecies(id: "kawakawa", commonName: "Kawakawa", origin: .native),
            makeSpecies(id: "karengo", commonName: "Karengo", origin: .native),
            makeSpecies(id: "blackberry", commonName: "Blackberry", origin: .pest)
        ]))

        await store.loadIfNeeded()

        #expect(store.filter(query: "kawa", origin: .native).map(\.id) == ["kawakawa"])
        #expect(store.filter(query: "kawa", origin: .pest).isEmpty)
    }

    @Test("No filters returns the whole catalogue")
    func filterWithNoConstraints() async {
        let store = SpeciesStore(repository: StubRepository(species: [
            makeSpecies(id: "a", origin: .native),
            makeSpecies(id: "b", origin: .pest)
        ]))

        await store.loadIfNeeded()

        #expect(store.filter().map(\.id) == ["a", "b"])
    }

    @Test("An empty or whitespace query returns the whole catalogue")
    func emptySearch() async {
        let store = SpeciesStore(repository: StubRepository(species: [
            makeSpecies(id: "a"),
            makeSpecies(id: "b")
        ]))

        await store.loadIfNeeded()

        #expect(store.search("").count == 2)
        #expect(store.search("   ").count == 2)
    }
}
