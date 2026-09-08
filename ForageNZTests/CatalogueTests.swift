import ForageCatalogue
import Foundation
import Testing

@testable import ForageNZ

/// Integrity checks against the real shipped catalogue.
///
/// This is a safety-critical dataset: a missing warning or an unexplained lookalike is a
/// product defect, not a content nicety. These tests fail the build when one slips in.
@Suite("Shipped catalogue")
struct CatalogueTests {
    /// Entries drafted from general knowledge and not yet checked against a field guide.
    ///
    /// Delete an id once its `sources` are filled in. The two tests below enforce both
    /// directions, so this list can only shrink: a new entry with no sources fails, and an
    /// id left here after being sourced also fails.
    ///
    /// Verify in this order — these make lethal claims:
    /// tutu, death-cap, karaka, wild-fennel, field-mushroom, nettle, sea-celery.
    private static let pendingVerification: Set<String> = [
        // Lethal claims — highest priority.
        "tutu", "death-cap", "karaka", "wild-fennel", "field-mushroom", "nettle", "sea-celery",
        // Need care: processing requirements or toxic parts.
        "watercress", "chickweed", "elderflower", "rosehip", "poroporo", "sweet-chestnut",
        "slippery-jack", "saffron-milk-cap", "pikopiko", "kawakawa", "bull-kelp", "sea-lettuce",
        // Straightforward.
        "puha", "dandelion", "miners-lettuce", "horopito", "nasturtium", "blackberry", "feijoa",
        "wild-plum", "cherry-guava", "wood-ear", "karengo", "walnut"
    ]

    private func loadCatalogue() async throws -> [ForageSpecies] {
        try await BundledSpeciesRepository().loadSpecies()
    }

    @Test("Every unsourced entry is on the known pending-verification list")
    func unsourcedEntriesAreDeclared() async throws {
        for entry in try await loadCatalogue() where !entry.isVerified {
            #expect(
                Self.pendingVerification.contains(entry.id),
                "\(entry.id) has no sources and is not declared pending — fill in sources before shipping it"
            )
        }
    }

    @Test("The pending-verification list has no stale or unknown ids")
    func pendingVerificationListIsCurrent() async throws {
        let catalogue = try await loadCatalogue()
        let ids = Set(catalogue.map(\.id))

        for pending in Self.pendingVerification {
            #expect(ids.contains(pending), "\(pending) is declared pending but is not in the catalogue")
        }

        for entry in catalogue where entry.isVerified {
            #expect(
                !Self.pendingVerification.contains(entry.id),
                "\(entry.id) now has sources — remove it from pendingVerification"
            )
        }
    }

    @Test("The bundled catalogue decodes")
    func catalogueDecodes() async throws {
        let species = try await loadCatalogue()
        #expect(!species.isEmpty)
    }

    @Test("A missing catalogue throws the missing case, not a generic failure")
    func missingCatalogue() async {
        let repository = BundledSpeciesRepository(resourceName: "no-such-catalogue")
        await #expect(throws: SpeciesRepositoryError.catalogueMissing(resourceName: "no-such-catalogue")) {
            try await repository.loadSpecies()
        }
    }

    @Test("Identifiers are unique")
    func uniqueIdentifiers() async throws {
        let species = try await loadCatalogue()
        let ids = species.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Every entry has the text the detail screen renders")
    func requiredTextPresent() async throws {
        for entry in try await loadCatalogue() {
            #expect(!entry.commonName.isEmpty, "\(entry.id) has no common name")
            #expect(!entry.scientificName.isEmpty, "\(entry.id) has no scientific name")
            #expect(!entry.summary.isEmpty, "\(entry.id) has no summary")
            #expect(!entry.habitat.isEmpty, "\(entry.id) has no habitat")
            #expect(!entry.identification.isEmpty, "\(entry.id) has no identification notes")
        }
    }

    @Test("Every lookalike explains how to tell them apart")
    func lookalikesAreActionable() async throws {
        for entry in try await loadCatalogue() {
            for lookalike in entry.lookalikes {
                #expect(!lookalike.name.isEmpty, "\(entry.id) has an unnamed lookalike")
                #expect(
                    !lookalike.howToTell.isEmpty,
                    "\(entry.id) lists \(lookalike.name) with no way to tell them apart"
                )
            }
        }
    }

    @Test("Anything with a deadly lookalike is never marked straightforward")
    func deadlyLookalikesRaiseCaution() async throws {
        for entry in try await loadCatalogue() where entry.highestLookalikeRisk == .deadly {
            #expect(
                entry.caution != .straightforward,
                "\(entry.id) has a deadly lookalike but is marked straightforward"
            )
        }
    }

    @Test("Do-not-eat entries carry warnings and claim no edible parts")
    func doNotEatEntriesAreExplicit() async throws {
        let doNotEat = try await loadCatalogue().filter { $0.caution == .doNotEat }
        #expect(!doNotEat.isEmpty, "The guide should teach avoidance, not only collection")

        for entry in doNotEat {
            #expect(!entry.warnings.isEmpty, "\(entry.id) is do-not-eat but carries no warnings")
            #expect(
                entry.edibleParts.localizedCaseInsensitiveContains("none"),
                "\(entry.id) is do-not-eat but lists edible parts"
            )
        }
    }

    @Test("Care-required entries explain the risk")
    func careRequiredEntriesExplainThemselves() async throws {
        for entry in try await loadCatalogue() where entry.caution == .careRequired {
            #expect(
                !entry.warnings.isEmpty || !entry.lookalikes.isEmpty,
                "\(entry.id) needs care but says neither why nor what it resembles"
            )
        }
    }

    @Test("Native species carry harvesting guidance")
    func nativeSpeciesHaveEthics() async throws {
        for entry in try await loadCatalogue() where entry.origin == .native {
            #expect(
                entry.harvestEthics?.isEmpty == false,
                "\(entry.id) is native but has no harvesting or tikanga guidance"
            )
        }
    }

    @Test("Every origin has at least one entry, so the origin filter has no dead options")
    func originsArePopulated() async throws {
        let species = try await loadCatalogue()
        for origin in ForageOrigin.allCases {
            #expect(
                species.contains { $0.origin == origin },
                "No entries with origin \(origin.displayName)"
            )
        }
    }

    @Test("Every category has at least one entry")
    func categoriesArePopulated() async throws {
        let species = try await loadCatalogue()
        for category in ForageCategory.allCases {
            #expect(
                species.contains { $0.category == category },
                "No entries in \(category.displayName)"
            )
        }
    }

    @Test("Every month has something to look for")
    func everyMonthHasSomething() async throws {
        let species = try await loadCatalogue()
        for month in ForageMonth.allCases {
            let inSeason = species.filter { $0.caution != .doNotEat && $0.isInSeason(in: month) }
            #expect(!inSeason.isEmpty, "Nothing to forage in \(month.displayName)")
        }
    }
}
