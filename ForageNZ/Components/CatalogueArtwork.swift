import SwiftUI

/// The single mapping from a classification to its drawing, the counterpart to
/// `CautionPalette` doing it for colour.
///
/// It lives here rather than on the enums because the enums live in `ForageCatalogue`, which
/// has to keep building with `swift build` for `catalogue-tool`. The SwiftPM command line
/// copies an asset catalog verbatim instead of running `actool`, so artwork shipped in the
/// package would neither compile nor generate symbols. Here, Xcode compiles the catalog for
/// both the app and the editor, and every case below is a generated `ImageResource` — rename
/// an image set and this file stops compiling, which is the whole point of naming them this
/// way rather than by string.

/// A classification the user can filter the guide by: it has a name to show and a drawing to
/// show beside it. Conformance is declared here rather than in `Model/` because `image` is
/// app-side for the reason above, and a protocol is only worth it once something is generic
/// over these — `BrowseView`'s filter menu, which would otherwise be the same code per enum.
protocol CatalogueFacet: CaseIterable, Identifiable, Hashable {
    var displayName: LocalizedStringResource { get }
    var image: Image { get }
}

extension ForageGroup: CatalogueFacet {}
extension ForageOrigin: CatalogueFacet {}

extension Habitat {
    var image: Image {
        switch self {
        // Drawn as a shoreline; the habitat is the whole coast, dunes and estuaries
        // included. The case name is the one that has to stay right.
        case .coastal: Image(.shore)
        case .forest: Image(.forest)
        case .shrubland: Image(.shrubland)
        case .grassland: Image(.grassland)
        case .wetland: Image(.wetland)
        case .alpine: Image(.alpine)
        case .urban: Image(.urban)
        case .disturbed: Image(.disturbed)
        }
    }
}

extension ForageGroup {
    var image: Image {
        switch self {
        case .greens: Image(.greens)
        case .herbs: Image(.herbs)
        // The group is singular, the image set is plural. Not worth renaming either.
        case .fruit: Image(.fruits)
        case .fungi: Image(.fungi)
        case .seaweed: Image(.seaweed)
        case .nuts: Image(.nuts)
        }
    }
}

extension ForageOrigin {
    var image: Image {
        switch self {
        // Endemic and native share a drawing. They are the two cases `isIndigenous` covers
        // and they carry the same harvest obligation, which is what the icon is signalling;
        // `displayName` is what tells the two apart.
        case .endemic, .native: Image(.endemic)
        case .introduced: Image(.introduced)
        // "Invasive" on the artwork, `pest` in the model — the model word is the one the
        // catalogue and the harvest guidance use.
        case .pest: Image(.invasive)
        }
    }
}

extension LookalikeRisk {
    var image: Image {
        switch self {
        case .deadly: Image(.deadly)
        case .toxic: Image(.toxic)
        case .unpalatable: Image(.unpalatable)
        // Neither has a drawing of its own: each borrows the symbol its `CautionLevel`
        // counterpart uses, so the same claim looks the same wherever the app makes it.
        case .edible: Image(systemName: "checkmark.seal")
        case .psychoactive: Image(systemName: "brain.head.profile")
        }
    }
}

extension CautionLevel {
    /// The one classification with no drawing of its own — a badge this small reads better
    /// as a symbol, and the colour is already carrying the meaning.
    var image: Image {
        switch self {
        case .straightforward: Image(systemName: "checkmark.seal")
        case .careRequired: Image(systemName: "exclamationmark.triangle")
        case .doNotEat: Image(systemName: "xmark.octagon")
        case .psychoactive: Image(systemName: "brain.head.profile")
        }
    }
}
