import Foundation

/// A single wild food entry in the field guide.
public nonisolated struct ForageSpecies: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let commonName: String
    /// Te reo Māori name, where the species has one in common use.
    public let maoriName: String?
    public let scientificName: String
    public let group: ForageGroup
    public let origin: ForageOrigin
    public let caution: CautionLevel
    /// Months worth looking. Empty means available year-round.
    public let months: [ForageMonth]
    /// One-line hook shown in lists.
    public let summary: SourcedText
    public let habitat: SourcedText
    /// The habitat prose as a filterable classification. Empty means nobody has classified
    /// this entry yet — it is never a claim that the species grows nowhere.
    public let habitats: [Habitat]
    public let identification: SourcedText
    public let edibleParts: SourcedText
    public let preparation: SourcedText
    public let lookalikes: [Lookalike]
    /// Hard safety facts — processing requirements, toxic parts, contamination risks.
    public let warnings: [String]
    /// Tikanga, access and conservation notes: rāhui, DOC land, taking sparingly.
    public let harvestEthics: SourcedText?
    /// Where this entry's claims were checked. Empty means unverified.
    public let sources: [String]
    public let recipes: [Recipe]
    public let photos: [SpeciesPhoto]
    /// Where to see more photographs — an iNaturalist taxon page, usually.
    public let moreImagesURL: URL?
    /// A stub someone is still writing. Drafts ship in the catalogue file so the editor and
    /// tests see them, but the app never lists one — half an entry is worse than none in
    /// the field. Defaults to `false` when the key is missing.
    public let draft: Bool
    /// Set once the web has been searched for this species and found to hold nothing usable,
    /// so the remaining prose can only come off a printed page. `false` is the honest default
    /// for an absent key: it means nobody has looked, **not** that a search came back clean.
    /// Kept separate from `draft` and `isVerified` because it answers a different question —
    /// not "is this written" or "is this cited", but "is there any point searching again".
    public let needsBookSource: Bool
    /// Which book to reach for, and why the web could not do it. Read beside
    /// `needsBookSource`; a flag without one of these leaves the next person no better off
    /// than an untagged entry, which is what the validation advisory is there to catch.
    public let sourcingNote: String?

    public init(
        id: String,
        commonName: String,
        maoriName: String? = nil,
        scientificName: String,
        group: ForageGroup,
        origin: ForageOrigin,
        caution: CautionLevel,
        months: [ForageMonth] = [],
        summary: SourcedText,
        habitat: SourcedText,
        habitats: [Habitat] = [],
        identification: SourcedText,
        edibleParts: SourcedText,
        preparation: SourcedText,
        lookalikes: [Lookalike] = [],
        warnings: [String] = [],
        harvestEthics: SourcedText? = nil,
        sources: [String] = [],
        recipes: [Recipe] = [],
        photos: [SpeciesPhoto] = [],
        moreImagesURL: URL? = nil,
        draft: Bool = false,
        needsBookSource: Bool = false,
        sourcingNote: String? = nil
    ) {
        self.id = id
        self.commonName = commonName
        self.maoriName = maoriName
        self.scientificName = scientificName
        self.group = group
        self.origin = origin
        self.caution = caution
        self.months = months
        self.summary = summary
        self.habitat = habitat
        self.habitats = habitats
        self.identification = identification
        self.edibleParts = edibleParts
        self.preparation = preparation
        self.lookalikes = lookalikes
        self.warnings = warnings
        self.harvestEthics = harvestEthics
        self.sources = sources
        self.recipes = recipes
        self.photos = photos
        self.moreImagesURL = moreImagesURL
        self.draft = draft
        self.needsBookSource = needsBookSource
        self.sourcingNote = sourcingNote
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        commonName = try container.decode(String.self, forKey: .commonName)
        maoriName = try container.decodeIfPresent(String.self, forKey: .maoriName)
        scientificName = try container.decode(String.self, forKey: .scientificName)
        group = try container.decode(ForageGroup.self, forKey: .group)
        origin = try container.decode(ForageOrigin.self, forKey: .origin)
        caution = try container.decode(CautionLevel.self, forKey: .caution)
        months = try container.decode([ForageMonth].self, forKey: .months)
        summary = try container.decode(SourcedText.self, forKey: .summary)
        habitat = try container.decode(SourcedText.self, forKey: .habitat)
        // Absent means unclassified, like `draft`: an entry written before the field existed
        // still decodes, and the validation advisory is what asks for it to be filled in.
        habitats = try container.decodeIfPresent([Habitat].self, forKey: .habitats) ?? []
        identification = try container.decode(SourcedText.self, forKey: .identification)
        edibleParts = try container.decode(SourcedText.self, forKey: .edibleParts)
        preparation = try container.decode(SourcedText.self, forKey: .preparation)
        lookalikes = try container.decode([Lookalike].self, forKey: .lookalikes)
        warnings = try container.decode([String].self, forKey: .warnings)
        harvestEthics = try container.decodeIfPresent(SourcedText.self, forKey: .harvestEthics)
        sources = try container.decode([String].self, forKey: .sources)
        recipes = try container.decode([Recipe].self, forKey: .recipes)
        photos = try container.decode([SpeciesPhoto].self, forKey: .photos)
        moreImagesURL = try container.decodeIfPresent(URL.self, forKey: .moreImagesURL)
        draft = try container.decodeIfPresent(Bool.self, forKey: .draft) ?? false
        // Absent means nobody has searched, the same treatment `draft` and `habitats` get.
        needsBookSource = try container.decodeIfPresent(Bool.self, forKey: .needsBookSource) ?? false
        sourcingNote = try container.decodeIfPresent(String.self, forKey: .sourcingNote)
    }

    /// `true` once someone has checked this entry against a field guide.
    public var isVerified: Bool { !sources.isEmpty }

    /// This entry as a compile-time value. `nil` only for a species added since `SpeciesID`
    /// was last generated — a state the tests do not allow to ship.
    public var typedID: SpeciesID? { SpeciesID(rawValue: id) }

    /// `true` when the species has no seasonal window and is worth looking for at any time.
    public var isYearRound: Bool { months.isEmpty }

    /// Year-round species are in season in every month.
    public func isInSeason(in month: ForageMonth) -> Bool {
        isYearRound || months.contains(month)
    }

    /// A human-readable season window, e.g. "Feb – Apr", "Nov – Feb" or "Year-round".
    ///
    /// Each contiguous run collapses to its own range, and the ranges are joined:
    /// elder's two harvests read "Sep – Dec, Feb – Apr" rather than spelling out seven
    /// months. Every run is listed rather than spanning first to last, because the gaps
    /// are real — elder has nothing to pick in January, and a row claiming otherwise
    /// sends someone out after green berries.
    ///
    /// Seasons are treated as circular, because southern-hemisphere seasons routinely wrap
    /// the new year — a plain numeric sort would render Nov–Feb as "Jan, Feb, Nov, Dec".
    public var seasonDescription: String {
        guard !months.isEmpty else { return "Year-round" }
        let ordered = orderedSeasonMonths
        guard ordered.count > 1 else { return ordered[0].displayName }
        guard ordered.count < ForageMonth.count else { return "Year-round" }

        return contiguousSeasonRuns(in: ordered)
            .map { run in
                run.count > 1 ? "\(run[0].shortName) – \(run[run.count - 1].shortName)" : run[0].shortName
            }
            .joined(separator: ", ")
    }

    /// Splits months already in reading order into runs of consecutive months.
    private func contiguousSeasonRuns(in ordered: [ForageMonth]) -> [[ForageMonth]] {
        var runs: [[ForageMonth]] = []
        var run: [ForageMonth] = []
        for month in ordered {
            if let previous = run.last, month.isImmediatelyAfter(previous) {
                run.append(month)
            } else {
                if !run.isEmpty { runs.append(run) }
                run = [month]
            }
        }
        if !run.isEmpty { runs.append(run) }
        return runs
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
        [commonName, maoriName, scientificName, summary.text]
            .compactMap(\.self)
            .joined(separator: " ")
            .lowercased()
    }

    /// The worst lookalike risk attached to this species, if any — used to surface
    /// a deadly-confusion warning before the user goes looking.
    public var highestLookalikeRisk: LookalikeRisk? {
        lookalikes.map(\.risk).max()
    }

    /// The one rule behind every "deadly lookalike" badge and banner: an edible whose double
    /// can kill. An entry nobody may take does not get the badge — a do-not-eat entry is the
    /// danger itself, and a psychoactive one is not being offered as food either.
    public var hasDeadlyLookalikeAsEdible: Bool {
        highestLookalikeRisk == .deadly && caution.isHarvestable
    }

    /// A copy with one field replaced. The model is immutable by design, so the editor
    /// rebuilds an entry rather than mutating it.
    public func with(
        commonName: String? = nil,
        maoriName: String?? = nil,
        scientificName: String? = nil,
        group: ForageGroup? = nil,
        origin: ForageOrigin? = nil,
        caution: CautionLevel? = nil,
        months: [ForageMonth]? = nil,
        summary: SourcedText? = nil,
        habitat: SourcedText? = nil,
        habitats: [Habitat]? = nil,
        identification: SourcedText? = nil,
        edibleParts: SourcedText? = nil,
        preparation: SourcedText? = nil,
        lookalikes: [Lookalike]? = nil,
        warnings: [String]? = nil,
        harvestEthics: SourcedText?? = nil,
        sources: [String]? = nil,
        recipes: [Recipe]? = nil,
        photos: [SpeciesPhoto]? = nil,
        moreImagesURL: URL?? = nil,
        draft: Bool? = nil,
        needsBookSource: Bool? = nil,
        sourcingNote: String?? = nil
    ) -> ForageSpecies {
        ForageSpecies(
            id: id,
            commonName: commonName ?? self.commonName,
            maoriName: maoriName ?? self.maoriName,
            scientificName: scientificName ?? self.scientificName,
            group: group ?? self.group,
            origin: origin ?? self.origin,
            caution: caution ?? self.caution,
            months: months ?? self.months,
            summary: summary ?? self.summary,
            habitat: habitat ?? self.habitat,
            habitats: habitats ?? self.habitats,
            identification: identification ?? self.identification,
            edibleParts: edibleParts ?? self.edibleParts,
            preparation: preparation ?? self.preparation,
            lookalikes: lookalikes ?? self.lookalikes,
            warnings: warnings ?? self.warnings,
            harvestEthics: harvestEthics ?? self.harvestEthics,
            sources: sources ?? self.sources,
            recipes: recipes ?? self.recipes,
            photos: photos ?? self.photos,
            moreImagesURL: moreImagesURL ?? self.moreImagesURL,
            draft: draft ?? self.draft,
            needsBookSource: needsBookSource ?? self.needsBookSource,
            sourcingNote: sourcingNote ?? self.sourcingNote
        )
    }

    /// The one ordering every list of species uses — app, editor sidebar, verification
    /// queue. Ties on common name break on id, because `sort` is not stable and two entries
    /// with the same name would otherwise swap places between runs.
    public static func displayOrder(_ lhs: ForageSpecies, _ rhs: ForageSpecies) -> Bool {
        switch lhs.commonName.localizedCaseInsensitiveCompare(rhs.commonName) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame: lhs.id < rhs.id
        }
    }
}
