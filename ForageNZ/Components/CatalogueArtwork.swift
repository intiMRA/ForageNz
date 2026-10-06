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

/// How a badge draws its image.
///
/// Every icon in this app is a silhouette taking the badge's foreground colour — except one.
/// `DesignLibrary.icon(size:color:)` forces `renderingMode(.template)`, which flattens a
/// drawing to a single colour, and the psychoactive mushrooms are drawn in their own pinks.
enum BadgeIcon {
    /// A silhouette, tinted to the badge's foreground.
    case tinted(Image)
    /// Artwork that carries its own colours, drawn as it was drawn.
    case original(Image)

    /// The artwork itself, for the places that draw it outside a badge — the detail page's
    /// banners, which are `careRequired` and `doNotEat` and so always tinted.
    var image: Image {
        switch self {
        case .tinted(let image), .original(let image): image
        }
    }
}

extension LookalikeRisk {
    var badgeIcon: BadgeIcon {
        switch self {
        case .deadly: .tinted(Image(.deadly))
        case .toxic: .tinted(Image(.toxic))
        case .unpalatable: .tinted(Image(.unpalatable))
        // Drawn in its own colours, and shared with `CautionLevel.psychoactive`.
        case .psychoactive: .original(Image(.psychoactive))
        // The one with no drawing of its own: it borrows the symbol its `CautionLevel`
        // counterpart uses, so the same claim looks the same wherever the app makes it.
        case .edible: .tinted(Image(systemName: "checkmark.seal"))
        // Drawn for this case alone: `CautionLevel` has no "not known" counterpart to borrow
        // from, because an entry always states how much care it wants even when the
        // literature says nothing about eating it.
        case .unknown: .tinted(Image(.unknown))
        }
    }

    var image: Image { badgeIcon.image }
}

extension CautionLevel {
    /// Mostly symbols rather than drawings — a badge this small reads better as one, and the
    /// colour is already carrying the meaning. `psychoactive` is the exception twice over: the
    /// only case with artwork of its own, and the only one that keeps its own colours.
    var badgeIcon: BadgeIcon {
        switch self {
        case .straightforward: .tinted(Image(systemName: "checkmark.seal"))
        case .careRequired: .tinted(Image(systemName: "exclamationmark.triangle"))
        case .doNotEat: .tinted(Image(systemName: "xmark.octagon"))
        case .psychoactive: .original(Image(.psychoactive))
        }
    }

    var image: Image { badgeIcon.image }
}
