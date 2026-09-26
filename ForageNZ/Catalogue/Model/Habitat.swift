import Foundation

/// The kind of place a species grows, as a filterable classification.
///
/// This is the structured companion to `ForageSpecies.habitat`, which stays the prose a
/// forager actually reads. The prose says "roadsides, riverbanks, gullies, forest margins,
/// abandoned farmland"; this says `[.disturbed, .wetland, .forest, .grassland]`, so the app
/// can answer "what can I find on the coast" without parsing sentences.
///
/// Deliberately coarse. Eight buckets can be assigned from a habitat paragraph without a
/// judgement call on every entry, and each one stays meaningful as a filter — a list of
/// twenty near-synonyms would split the catalogue into slices too thin to browse. The
/// precision lives in the prose, which is where a forager needs it.
///
/// Every case is a place, not a thing found in it — **and so is every label**. A roadside is
/// infrastructure and a garden is a land use; neither is a habitat. What makes a verge worth
/// searching is that the ground has been disturbed and left (`disturbed`, which equally
/// covers a building site with no road in sight), and what makes a garden worth searching is
/// that it is the built environment (`urban`). Both cases were right and both labels were
/// wrong, twice over, because a label naming a vivid example reads as the whole class of places.
/// `displayName` is therefore always "<habitat> & <example>", never the example alone, and
/// `shortLabel` drops the example rather than the habitat — a chip is where the temptation to
/// keep the vivid half is strongest, and where the misreading costs the most.
public nonisolated enum Habitat: String, Codable, Sendable, CaseIterable, Identifiable {
    /// The sea's edge: rocky shore and intertidal zone, sand dunes, estuaries and saltmarsh.
    case coastal
    /// Under a canopy, native or exotic — bush, woodland, plantation — and forest margins.
    case forest
    /// Low woody cover: regenerating scrub, mānuka and kānuka, gorse and broom, hedgerows
    /// and shelter belts. A vegetation community, in the sense DOC and the LCDB use it.
    case shrubland
    /// Open grass: pasture, paddocks, meadows, lawns and playing fields.
    case grassland
    /// Fresh water and the ground that stays wet — riverbanks, streamsides, swamp, bog.
    case wetland
    /// Above the treeline, and the tussock and herbfield just below it.
    case alpine
    /// Where people live: gardens, parks, street plantings, suburban berms.
    case urban
    /// Ground broken and then abandoned — verges, waste ground, railway margins, building
    /// sites, old farmland gone back to weeds. Ruderal, in the ecological term.
    case disturbed

    public var id: String { rawValue }

    public var displayName: LocalizedStringResource {
        switch self {
        case .coastal: "Coast & shore"
        case .forest: "Forest & bush"
        case .shrubland: "Shrubland & hedgerow"
        case .grassland: "Grassland & pasture"
        case .wetland: "Wetland & riverbank"
        case .alpine: "Alpine & tussock"
        case .urban: "Urban & gardens"
        case .disturbed: "Disturbed & waste ground"
        }
    }

    /// The short form, for chips and other places a full label will not fit.
    public var shortLabel: LocalizedStringResource {
        switch self {
        case .coastal: "Coast"
        case .forest: "Forest"
        case .shrubland: "Shrubland"
        case .grassland: "Grassland"
        case .wetland: "Wetland"
        case .alpine: "Alpine"
        case .urban: "Urban"
        // "Disturbed" alone is an adjective left hanging, so this one keeps its noun.
        case .disturbed: "Disturbed ground"
        }
    }
}
