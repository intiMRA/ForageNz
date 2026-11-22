import Foundation

/// A living partner this species depends on, and the page that partner has.
///
/// Only partnerships that need one particular other species: a root partner, a host or
/// parasite, or the one tree whose dead wood a fungus rots. A fungus that rots any dead wood
/// has no association; its habitat text says where it grows.
public nonisolated struct Association: Codable, Sendable, Hashable {
    public let kind: AssociationKind
    /// Typed like `Lookalike.entry`: an unknown id fails to decode, so a link can only name a
    /// species the catalogue has.
    public let entry: SpeciesID
    /// One short line for the card, e.g. "Its only root partner in New Zealand."
    public let note: String

    public init(kind: AssociationKind, entry: SpeciesID, note: String) {
        self.kind = kind
        self.entry = entry
        self.note = note
    }
}

public nonisolated enum AssociationKind: String, Codable, Sendable, CaseIterable {
    /// Root partner. Symmetric: both entries carry this kind.
    case mycorrhizalPartner
    case parasiteOf
    case hostOf
    case growsOnDeadWoodOf
    case deadWoodHostOf

    /// The kind the partner's entry carries for the same partnership.
    public var reverse: AssociationKind {
        switch self {
        case .mycorrhizalPartner: .mycorrhizalPartner
        case .parasiteOf: .hostOf
        case .hostOf: .parasiteOf
        case .growsOnDeadWoodOf: .deadWoodHostOf
        case .deadWoodHostOf: .growsOnDeadWoodOf
        }
    }

    public var displayName: String {
        switch self {
        case .mycorrhizalPartner: "Root partner"
        case .parasiteOf: "Parasite of"
        case .hostOf: "Host of"
        case .growsOnDeadWoodOf: "Rots the dead wood of"
        case .deadWoodHostOf: "Dead wood rotted by"
        }
    }
}

/// One directed partnership, catalogue-wide: what `species.json` must hold for both sides of
/// a link to agree.
public nonisolated struct AssociationLink: Sendable, Hashable {
    public let from: SpeciesID
    public let kind: AssociationKind
    public let to: SpeciesID

    public init(from: SpeciesID, kind: AssociationKind, to: SpeciesID) {
        self.from = from
        self.kind = kind
        self.to = to
    }

    /// Every link in the catalogue whose partner does not link back. Empty means every
    /// partnership is recorded on both pages.
    public static func oneWay(in catalogue: [ForageSpecies]) -> [AssociationLink] {
        let links = catalogue.flatMap { species -> [AssociationLink] in
            guard let owner = species.typedID else { return [] }
            return species.associations.map { AssociationLink(from: owner, kind: $0.kind, to: $0.entry) }
        }
        let recorded = Set(links)
        return links.filter { link in
            !recorded.contains(AssociationLink(from: link.to, kind: link.kind.reverse, to: link.from))
        }
    }
}
