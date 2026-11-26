import Foundation

/// Something a species is gathered for other than eating — fibre, dye, craft or cosmetics.
///
/// The food use is not one of these: it is the entry's own `edibleParts`, `preparation`,
/// `warnings` and `recipes`, left where they were so no shipped food page changes
/// (`docs/plans/useful-plants.md`, *Model, as built*). `caution` keeps meaning "can I eat it";
/// what handling a use asks of you goes in that use's `warnings`, so a dye plant can be
/// "do not eat" and "wear gloves" at once without either reading as the other.
public nonisolated struct SpeciesUse: Codable, Sendable, Hashable {
    public let kind: UseKind
    /// The part gathered for this use — leaves, inner bark, flower heads.
    public let parts: SourcedText
    /// When that part can be gathered. Empty means any time of year, the same rule as the
    /// entry's own `months` (owner, 12/10/2026): it dates the collected part, not the plant.
    public let months: [ForageMonth]
    /// How the part is processed: retting, mordanting, infusing. Safety text — written by a
    /// person or restated from a trusted source, never by a model.
    public let method: SourcedText
    /// Handling dangers for this use: sap, fumes, lye, mordants.
    public let warnings: [String]
    public let recipes: [Recipe]

    public init(
        kind: UseKind,
        parts: SourcedText,
        months: [ForageMonth] = [],
        method: SourcedText,
        warnings: [String] = [],
        recipes: [Recipe] = []
    ) {
        self.kind = kind
        self.parts = parts
        self.months = months
        self.method = method
        self.warnings = warnings
        self.recipes = recipes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(UseKind.self, forKey: .kind)
        parts = try container.decode(SourcedText.self, forKey: .parts)
        months = try container.decodeIfPresent([ForageMonth].self, forKey: .months) ?? []
        method = try container.decode(SourcedText.self, forKey: .method)
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
        recipes = try container.decodeIfPresent([Recipe].self, forKey: .recipes) ?? []
    }
}

/// The non-food uses in scope (owner, 26/11/2026). Medicinal use is deliberately absent: a
/// medicinal claim is the riskiest safety text there is, and few trusted open sources make one.
public nonisolated enum UseKind: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Weaving, basketry, cordage.
    case fibre
    case dye
    /// Tinder, soap plants and similar household materials.
    case craft
    /// Infused oils, balms, salves, soap, bath preparations and hair rinses — cosmetic, never
    /// medicinal. Named skin care until the owner renamed it (26/11/2026).
    case cosmetics

    public var id: String { rawValue }

    public var displayName: LocalizedStringResource {
        switch self {
        case .fibre: "Fibre & weaving"
        case .dye: "Dye"
        case .craft: "Craft & household"
        case .cosmetics: "Cosmetics"
        }
    }
}
