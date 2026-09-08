import Foundation

/// A single wild food entry in the field guide.
public nonisolated struct ForageSpecies: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let commonName: String
    /// Te reo Māori name, where the species has one in common use.
    public let maoriName: String?
    public let scientificName: String
    public let category: ForageCategory
    public let origin: ForageOrigin
    public let caution: CautionLevel
    /// Months worth looking. Empty means available year-round.
    public let months: [ForageMonth]
    /// One-line hook shown in lists.
    public let summary: String
    public let habitat: String
    public let identification: String
    public let edibleParts: String
    public let preparation: String
    public let lookalikes: [Lookalike]
    /// Hard safety facts — processing requirements, toxic parts, contamination risks.
    public let warnings: [String]
    /// Tikanga, access and conservation notes: rāhui, DOC land, taking sparingly.
    public let harvestEthics: String?
    /// Where this entry's claims were checked. Empty means unverified.
    public let sources: [String]
    public let recipes: [Recipe]

    public init(
        id: String,
        commonName: String,
        maoriName: String? = nil,
        scientificName: String,
        category: ForageCategory,
        origin: ForageOrigin,
        caution: CautionLevel,
        months: [ForageMonth] = [],
        summary: String,
        habitat: String,
        identification: String,
        edibleParts: String,
        preparation: String,
        lookalikes: [Lookalike] = [],
        warnings: [String] = [],
        harvestEthics: String? = nil,
        sources: [String] = [],
        recipes: [Recipe] = []
    ) {
        self.id = id
        self.commonName = commonName
        self.maoriName = maoriName
        self.scientificName = scientificName
        self.category = category
        self.origin = origin
        self.caution = caution
        self.months = months
        self.summary = summary
        self.habitat = habitat
        self.identification = identification
        self.edibleParts = edibleParts
        self.preparation = preparation
        self.lookalikes = lookalikes
        self.warnings = warnings
        self.harvestEthics = harvestEthics
        self.sources = sources
        self.recipes = recipes
    }

    /// `true` once someone has checked this entry against a field guide.
    public var isVerified: Bool { !sources.isEmpty }

    /// `true` when the species has no seasonal window and is worth looking for at any time.
    public var isYearRound: Bool { months.isEmpty }

    /// Year-round species are in season in every month.
    public func isInSeason(in month: ForageMonth) -> Bool {
        isYearRound || months.contains(month)
    }

    /// A human-readable season window, e.g. "Feb – Apr", "Nov – Feb" or "Year-round".
    ///
    /// Contiguous runs collapse to a range; scattered months are listed individually.
    /// Seasons are treated as circular, because southern-hemisphere seasons routinely wrap
    /// the new year — a plain numeric sort would render Nov–Feb as "Jan, Feb, Nov, Dec".
    public var seasonDescription: String {
        guard !months.isEmpty else { return "Year-round" }
        let ordered = orderedSeasonMonths
        guard let first = ordered.first, let last = ordered.last else { return "Year-round" }
        guard ordered.count > 1 else { return first.displayName }
        guard ordered.count < ForageMonth.count else { return "Year-round" }

        let isContiguous = zip(ordered, ordered.dropFirst()).allSatisfy { $1.isImmediatelyAfter($0) }
        if isContiguous {
            return "\(first.shortName) – \(last.shortName)"
        }
        return ordered.map(\.shortName).joined(separator: ", ")
    }

    /// Months rotated so the run begins after the largest gap in the calendar circle,
    /// putting a year-wrapping season into reading order (Nov, Dec, Jan).
    private var orderedSeasonMonths: [ForageMonth] {
        let sorted = months.sorted()
        guard sorted.count > 1 else { return sorted }

        var startIndex = 0
        var largestGap = 0
        for index in sorted.indices {
            let previous = sorted[(index + sorted.count - 1) % sorted.count]
            let gap = sorted[index].monthsAfter(previous)
            if gap > largestGap {
                largestGap = gap
                startIndex = index
            }
        }
        return Array(sorted[startIndex...]) + Array(sorted[..<startIndex])
    }

    /// Text the search field matches against.
    public var searchableText: String {
        [commonName, maoriName, scientificName, summary]
            .compactMap(\.self)
            .joined(separator: " ")
            .lowercased()
    }

    /// The worst lookalike risk attached to this species, if any — used to surface
    /// a deadly-confusion warning before the user goes looking.
    public var highestLookalikeRisk: LookalikeRisk? {
        lookalikes.map(\.risk).max()
    }
}
