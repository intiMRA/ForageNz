import ForageCatalogue
import SwiftUI

// MARK: - Models

/// Everything a list row shows. A value, so it can be built and checked without a view.
struct ListingRowModel: Equatable {
    let speciesID: SpeciesID
    let commonName: String
    let scientificName: String
    let summary: String
    let caution: CautionLevel
    let categorySymbolName: String
    let seasonDescription: String
    let hasDeadlyLookalike: Bool
}

/// One "can be confused with" card, including where tapping it goes.
struct LookalikeCardModel: Equatable, Identifiable {
    let destination: SpeciesID
    let name: String
    let scientificName: String?
    let risk: LookalikeRisk
    let howToTell: String

    var id: String { "\(destination.rawValue)|\(name)" }
    /// Stable hook for UI tests: `lookalike.hemlock`.
    var accessibilityIdentifier: String { "lookalike.\(destination.rawValue)" }

    /// The mapping needs no catalogue, so it lives on the model and every factory shares it.
    init(_ lookalike: Lookalike) {
        destination = lookalike.entry
        name = lookalike.name
        scientificName = lookalike.scientificName
        risk = lookalike.risk
        howToTell = lookalike.howToTell
    }
}

/// The detail page: the entry itself plus its lookalike cards already resolved to destinations.
struct InfoPageModel: Equatable {
    let species: ForageSpecies
    let lookalikeCards: [LookalikeCardModel]
}

// MARK: - Factory

/// The only way a `SpeciesID` becomes something on screen.
///
/// Screens ask the factory for a model and construct the view themselves — the factory knows
/// the catalogue, the views know layout, and neither knows the other. Keyed by `SpeciesID`, a
/// compile-time value generated from the catalogue, so a species the catalogue lacks cannot be
/// asked for. A protocol so previews and tests inject a stub without a catalogue.
@MainActor
protocol SpeciesModelFactory {
    /// `nil` only if the enum and the catalogue have drifted, which the tests do not let ship.
    func createInfoPageModel(id: SpeciesID) -> InfoPageModel?
    func createListingRowModel(id: SpeciesID) -> ListingRowModel?
    /// Takes the `Lookalike` rather than a bare id: the card's text — how to tell them apart —
    /// belongs to the relationship between two species, not to the one it opens.
    func createLookalikeCardModel(_ lookalike: Lookalike) -> LookalikeCardModel
}

struct CatalogueSpeciesModelFactory: SpeciesModelFactory {
    let store: SpeciesStore

    func createInfoPageModel(id: SpeciesID) -> InfoPageModel? {
        guard let species = store.species(for: id) else { return nil }
        return InfoPageModel(
            species: species,
            lookalikeCards: species.lookalikes.map(createLookalikeCardModel)
        )
    }

    func createListingRowModel(id: SpeciesID) -> ListingRowModel? {
        guard let species = store.species(for: id) else { return nil }
        return ListingRowModel(
            speciesID: id,
            commonName: species.commonName,
            scientificName: species.scientificName,
            summary: species.summary,
            caution: species.caution,
            categorySymbolName: species.category.symbolName,
            seasonDescription: species.seasonDescription,
            // A do-not-eat entry is itself the danger; the badge is for edibles with a killer double.
            hasDeadlyLookalike: species.highestLookalikeRisk == .deadly && species.caution != .doNotEat
        )
    }

    func createLookalikeCardModel(_ lookalike: Lookalike) -> LookalikeCardModel {
        LookalikeCardModel(lookalike)
    }
}

/// What a view gets if nothing injected a factory: nothing, loudly. A default that quietly
/// produced real content would hide a wiring mistake.
struct UnconfiguredSpeciesModelFactory: SpeciesModelFactory {
    func createInfoPageModel(id: SpeciesID) -> InfoPageModel? { nil }
    func createListingRowModel(id: SpeciesID) -> ListingRowModel? { nil }
    func createLookalikeCardModel(_ lookalike: Lookalike) -> LookalikeCardModel {
        LookalikeCardModel(lookalike)
    }
}

extension EnvironmentValues {
    @Entry var speciesModels: any SpeciesModelFactory = UnconfiguredSpeciesModelFactory()
}
