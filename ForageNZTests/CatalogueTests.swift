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
    /// Entries not yet checked against anything.
    ///
    /// Empty, and the two tests below keep it that way: an entry with no sources fails unless
    /// it is declared here, and an id left here after being sourced fails too. A new entry
    /// goes on this list until someone has checked it.
    private static let pendingVerification: Set<String> = []

    private func loadCatalogue() async throws -> [ForageSpecies] {
        try await BundledSpeciesRepository().loadSpecies()
    }

    // MARK: - Per-entry rules, shared with the editor

    /// Drafts are exempt: they are stubs the app never lists, and being incomplete is what
    /// makes them drafts. `draftsAreStubsNotShippedContent` keeps that exemption honest.
    @Test("No shipped entry carries a blocking validation issue")
    func noBlockingIssues() async throws {
        for entry in try await loadCatalogue() where !entry.draft {
            for issue in entry.blockingIssues {
                Issue.record("\(entry.id) · \(issue.field): \(issue.message)")
            }
        }
    }

    @Test("Every draft is sourced and unfinished, never a way to ship an unchecked entry")
    func draftsAreStubsNotShippedContent() async throws {
        for entry in try await loadCatalogue() where entry.draft {
            #expect(entry.isVerified, "\(entry.id) is a draft with no source — where did its facts come from?")
            #expect(!entry.blockingIssues.isEmpty, "\(entry.id) passes validation, so it should no longer be a draft")
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
        for entry in try await loadCatalogue() where !entry.draft {
            #expect(
                !entry.identification.isBlank,
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

    /// `SpeciesID` is generated from the catalogue and checked in. If they disagree, either a
    /// species was added without regenerating (its rows could not navigate) or one was removed
    /// and something may still reference it. Both fail here, so neither ships.
    @Test("SpeciesID has exactly one case per catalogue entry")
    func speciesIDMatchesCatalogue() async throws {
        let ids = Set(try await loadCatalogue().map(\.id))
        let cases = Set(SpeciesID.allCases.map(\.rawValue))
        #expect(ids.subtracting(cases).isEmpty, "in the catalogue but not in SpeciesID — run catalogue-tool --normalise: \(ids.subtracting(cases))")
        #expect(cases.subtracting(ids).isEmpty, "in SpeciesID but not in the catalogue — stale case: \(cases.subtracting(ids))")
    }

    /// Lookalikes decode their `entry` as a `SpeciesID`, so a card that opens nothing is a
    /// load failure, not a runtime surprise. This asserts the load actually exercised that.
    ///
    /// A shipped card must open a shipped page: `SpeciesStore` drops drafts, so a card
    /// pointing at one would render `ContentUnavailableView` where it promised a species.
    @Test("Every lookalike card has a page to open")
    func everyLookalikeHasAnEntry() async throws {
        let species = try await loadCatalogue()
        let ids = Set(species.map(\.id))
        let shipped = Set(species.filter { !$0.draft }.map(\.id))
        for entry in species {
            for lookalike in entry.lookalikes {
                #expect(ids.contains(lookalike.entry.rawValue), "\(entry.id) → \(lookalike.name) names \(lookalike.entry.rawValue), which is not in the catalogue")
                if !entry.draft {
                    #expect(
                        shipped.contains(lookalike.entry.rawValue),
                        "\(entry.id) → \(lookalike.name) opens \(lookalike.entry.rawValue), which is still a draft and so is not in the app"
                    )
                }
            }
        }
    }

    /// A card can name any page, so this is what stops "Hemlock" opening the bitter-bolete page:
    /// when a lookalike records a scientific name, the page it opens must carry that name.
    @Test("Every lookalike opens the page whose scientific name it records")
    func lookalikeEntriesMatchTheirScientificNames() async throws {
        let species = try await loadCatalogue()
        let byID = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0) })
        for entry in species {
            for lookalike in entry.lookalikes {
                guard let scientific = lookalike.scientificName, let target = byID[lookalike.entry.rawValue] else { continue }
                let targetNames = target.scientificName.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                #expect(
                    targetNames.contains(scientific.lowercased()),
                    "\(entry.id) → \(lookalike.name) says \(scientific) but opens \(target.id) (\(target.scientificName))"
                )
            }
        }
    }

    /// A lookalike's `risk` describes the species the card *names*, not the pair. A confusable
    /// pair is carded from both sides, and it is the reverse card that goes wrong: hemlock's
    /// page carried "Wild fennel — Deadly", because there was no way to say the other one is
    /// the safe half until `LookalikeRisk.edible` existed. This is the check that says so.
    @Test("A lookalike's risk agrees with the caution on the page it opens")
    func lookalikeRiskMatchesItsEntry() async throws {
        let species = try await loadCatalogue()
        let byID = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0) })
        for entry in species {
            for lookalike in entry.lookalikes {
                guard let target = byID[lookalike.entry.rawValue] else { continue }

                if target.caution != .doNotEat {
                    #expect(
                        lookalike.risk != .toxic && lookalike.risk != .deadly,
                        "\(entry.id) → \(lookalike.name) is tagged \(lookalike.risk.rawValue), but \(target.id)'s own page says \(target.caution.rawValue)"
                    )
                } else {
                    #expect(
                        lookalike.risk != .edible,
                        "\(entry.id) → \(lookalike.name) is tagged edible, but \(target.id) is a do-not-eat entry"
                    )
                }
            }
        }
    }

    @Test("The guide teaches avoidance, not only collection")
    func includesDoNotEatEntries() async throws {
        let doNotEat = try await loadCatalogue().filter { $0.caution == .doNotEat }
        #expect(!doNotEat.isEmpty, "There should be entries that exist to be recognised and avoided")
    }

    /// Drafts are excluded throughout: the app never lists one, so a filter option backed
    /// only by drafts is a dead option to the person holding the phone.
    @Test("Every origin has at least one entry, so the origin filter has no dead options")
    func originsArePopulated() async throws {
        let species = try await loadCatalogue().filter { !$0.draft }
        for origin in ForageOrigin.allCases {
            #expect(
                species.contains { $0.origin == origin },
                "No entries with origin \(origin.displayName)"
            )
        }
    }

    @Test("Every group has at least one entry")
    func groupsArePopulated() async throws {
        let species = try await loadCatalogue().filter { !$0.draft }
        for group in ForageGroup.allCases {
            #expect(
                species.contains { $0.group == group },
                "No entries in \(group.displayName)"
            )
        }
    }

    @Test("Every month has something to look for")
    func everyMonthHasSomething() async throws {
        let species = try await loadCatalogue().filter { !$0.draft }
        for month in ForageMonth.allCases {
            let inSeason = species.filter { $0.caution != .doNotEat && $0.isInSeason(in: month) }
            #expect(!inSeason.isEmpty, "Nothing to forage in \(month.displayName)")
        }
    }
}
