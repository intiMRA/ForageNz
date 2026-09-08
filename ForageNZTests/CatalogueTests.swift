import ForageCatalogue
import Foundation
import Testing

@testable import ForageNZ

/// Integrity checks against the real shipped catalogue.
///
/// This is a safety-critical dataset: a missing warning or an unexplained lookalike is a
/// product defect, not a content nicety. Per-entry rules live in `ForageSpecies`'
/// `validationIssues` so the macOS editor shows them while you type; this suite enforces
/// them at build time, and covers the catalogue-wide rules the editor can't see.
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

    // MARK: - Per-entry rules, shared with the editor

    @Test("No entry carries a blocking validation issue")
    func noBlockingIssues() async throws {
        for entry in try await loadCatalogue() {
            for issue in entry.blockingIssues {
                Issue.record("\(entry.id) · \(issue.field): \(issue.message)")
            }
        }
    }

    // MARK: - Verification tracking

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

    // MARK: - Loading

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

    // MARK: - Offline guarantee

    /// The guide has to work with the radio off: there is no signal where it gets used.
    /// This asserts the catalogue and every photo it references resolve from the bundle
    /// alone, with no network involved.
    @Test("Everything the guide renders is present in the app bundle")
    func everythingResolvesOffline() async throws {
        let species = try await loadCatalogue()
        #expect(!species.isEmpty, "The catalogue itself must be bundled")

        let photoDirectory = Bundle.main.resourceURL?.appending(path: CataloguePhotos.directoryName)
        let directory = try #require(photoDirectory, "Photos/ is not in the bundle")

        for entry in species {
            for photo in entry.photos {
                let url = directory.appending(path: photo.fileName)
                #expect(
                    FileManager.default.fileExists(atPath: url.path),
                    "\(entry.id) references \(photo.fileName), which is not bundled — it would be a blank slot in the field"
                )
            }
        }
    }

    /// A web link is a planning aid, never the only route to something needed in the field.
    @Test("No entry depends on a web link for its identification content")
    func noEntryLeansOnTheWeb() async throws {
        for entry in try await loadCatalogue() {
            #expect(
                !entry.identification.isEmpty,
                "\(entry.id) has no identification text, so its only usable content would be online"
            )
        }
    }

    // MARK: - Catalogue-wide rules

    @Test("Identifiers are unique")
    func uniqueIdentifiers() async throws {
        let species = try await loadCatalogue()
        let ids = species.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("The guide teaches avoidance, not only collection")
    func includesDoNotEatEntries() async throws {
        let doNotEat = try await loadCatalogue().filter { $0.caution == .doNotEat }
        #expect(!doNotEat.isEmpty, "There should be entries that exist to be recognised and avoided")
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
