import SwiftUI

// MARK: - Models

/// Everything a list row shows. A value, so it can be built and checked without a view.
nonisolated struct ListingRowModel: Equatable {
    let speciesID: SpeciesID
    let photoFileName: String?
    let commonName: String
    let scientificName: String
    let summary: String
    let caution: CautionLevel
    /// The group itself, not an icon name: the row picks the drawing, and a `ForageGroup`
    /// keeps this model `Equatable` where a SwiftUI `Image` would not.
    let group: ForageGroup
    let seasonDescription: String
    /// Empty for an entry nobody has classified — the row then shows no habitat line at all,
    /// rather than an empty space where one belongs.
    let habitats: [Habitat]
    /// The entry is an unfinished draft, on screen only because the debug drawer asked for it.
    /// Always `false` in a build the user has, where drafts never leave `SpeciesStore`.
    ///
    /// Not `ForageSpecies.isVerified`, which asks the narrower question of whether the entry
    /// cites any source. Every draft does; none of them is finished.
    let isUnverified: Bool
}

/// One "can be confused with" card, including where tapping it goes.
nonisolated struct LookalikeCardModel: Equatable, Identifiable {
    let destination: SpeciesID
    let name: String
    let scientificName: String?
    let photoFileName: String?
    let risk: LookalikeRisk
    let howToTell: String

    var id: String { "\(destination.rawValue)|\(name)" }
    /// Stable hook for UI tests: `lookalike.hemlock`.
    var accessibilityIdentifier: String { "lookalike.\(destination.rawValue)" }

    /// The mapping needs no catalogue, so it lives on the model and every factory shares it —
    /// except the photo, which belongs to the entry the card opens and so has to be resolved
    /// by whoever holds the catalogue. A factory without one passes `nil` and the card draws
    /// its placeholder.
    init(_ lookalike: Lookalike, photoFileName: String? = nil) {
        self.destination = lookalike.entry
        self.name = lookalike.name
        self.scientificName = lookalike.scientificName
        self.photoFileName = photoFileName
        self.risk = lookalike.risk
        self.howToTell = lookalike.howToTell
    }
}

/// The detail page: the entry itself plus its lookalike cards already resolved to destinations.
nonisolated struct InfoPageModel: Equatable {
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
    /// `nil` for a draft, which the app never lists, or if the enum and the catalogue have
    /// drifted, which the tests do not let ship.
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
            photoFileName: species.photos.first?.fileName,
            commonName: species.commonName,
            scientificName: species.scientificName,
            summary: species.summary.text,
            caution: species.caution,
            group: species.group,
            seasonDescription: species.seasonDescription,
            habitats: species.habitats,
            isUnverified: species.draft
        )
    }

    func createLookalikeCardModel(_ lookalike: Lookalike) -> LookalikeCardModel {
        LookalikeCardModel(
            lookalike,
            photoFileName: store.species(for: lookalike.entry)?.photos.first?.fileName
        )
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
