import Foundation

/// How much care a species demands before anything goes in a basket.
///
/// This is deliberately the most prominent attribute in the UI. The app never asserts
/// that a plant in front of the user *is* a given species — it describes what to check.
public nonisolated enum CautionLevel: String, Codable, Sendable, CaseIterable {
    /// Distinctive enough that a careful beginner can identify it, and harmless if they get it wrong.
    case straightforward
    /// Has toxic lookalikes, or needs processing/cooking before it is safe.
    case careRequired
    /// Listed so it can be recognised and avoided. Never eat.
    case doNotEat
    /// Not poisonous, but its active compounds are controlled drugs, so taking it is a crime
    /// rather than a health risk. Kept apart from `doNotEat` because filing a non-toxic
    /// mushroom under a heading about poisoning is a claim that is simply untrue.
    case psychoactive

    public var displayName: LocalizedStringResource {
        switch self {
        case .straightforward: "Straightforward"
        case .careRequired: "Care required"
        case .doNotEat: "Do not eat"
        case .psychoactive: "Psychoactive"
        }
    }

    public var shortLabel: LocalizedStringResource {
        switch self {
        case .straightforward: "OK"
        case .careRequired: "Care"
        case .doNotEat: "Danger"
        case .psychoactive: "Psychoactive"
        }
    }

    /// Whether this is something the reader may take at all.
    ///
    /// The two reasons not to are different in kind — it will hurt you, or taking it is a
    /// crime — but every screen that asks "is this food?" wants them treated the same, and
    /// asking `!= .doNotEat` silently answered yes for anything added later.
    public var isHarvestable: Bool {
        switch self {
        case .straightforward, .careRequired: true
        case .doNotEat, .psychoactive: false
        }
    }

}

/// What happens if you eat the lookalike instead of the entry whose page you are on.
///
/// It describes the *named* species, not the pair — which is why `edible` has to exist. A
/// confusable pair is carded from both sides, and from a do-not-eat entry's page the species
/// it is confused with is usually the one you actually wanted. Without a case for that, the
/// reverse card had to repeat the dangerous entry's own risk, and hemlock's page told the
/// reader that wild fennel was deadly.
public nonisolated enum LookalikeRisk: String, Codable, Sendable, Comparable, CaseIterable {
    case deadly
    /// Will make you seriously unwell.
    case toxic
    case unpalatable
    /// Won't poison you, but its active compounds are controlled drugs. The counterpart to
    /// `CautionLevel.psychoactive`, and the reason it has to exist: from a deadly species'
    /// page the mushroom it is confused with may be neither dangerous nor `edible`, and a
    /// green "Edible" tick on a Class A species is the worst of the available lies.
    case psychoactive
    /// Nobody has recorded whether it is edible — not a hedge, a fact about the literature.
    ///
    /// It exists for New Zealand's endemics. The three endemic *Lactarius* on the iNaturalist
    /// NZ list (`novae-zelandiae`, `tawai`, `umerensis`) have all been described — McNabb did
    /// it in 1971 — but not one of those accounts says whether the mushroom can be eaten, and
    /// no later source does either. So the gap this case names is narrower than "nobody has
    /// written about it": the edibility is unrecorded, not the species.
    ///
    /// Their *pages* are a separate problem. McNabb's descriptions are in copyright and no
    /// openly licensed one exists, so `tawai` and `umerensis` cannot be filled without a
    /// person writing from the paper — they are drafts flagged `needsBookSource`, and the
    /// cards pointing at them from saffron milk cap's page open nothing until that happens.
    /// (`sp. 'Hauroko'` is harder still: six records, no name, no description.)
    ///
    /// Carding them needed a risk, and every other case was a claim: `toxic` asserts harm
    /// nobody has observed, `unpalatable` asserts a taste nobody has recorded, and `edible`
    /// is the dangerous lie.
    case unknown
    /// The safe member of the pair: no worse than the entry it is carded against, and
    /// usually the one the forager was looking for. Not a claim that it needs no care —
    /// that is its own entry's `caution` to state.
    case edible

    public var displayName: LocalizedStringResource {
        switch self {
        case .deadly: "Deadly"
        case .toxic: "Toxic"
        case .unpalatable: "Unpalatable"
        case .psychoactive: "Psychoactive"
        case .unknown: "Not known"
        case .edible: "Edible"
        }
    }

    /// Ordered by what it costs you to get the pair the wrong way round. `psychoactive` sits
    /// above `unpalatable` because a conviction outlasts a bad dinner, and below `toxic`
    /// because nothing about it will put you in hospital.
    ///
    /// `unknown` sits above those three and below `toxic`: an untested mushroom is ranked as
    /// the worse possibility, because the reader is the experiment. It cannot outrank `toxic`
    /// or `deadly`, which are harms somebody has actually observed.
    private var severityRank: Int {
        switch self {
        case .edible: 0
        case .unpalatable: 1
        case .psychoactive: 2
        case .unknown: 3
        case .toxic: 4
        case .deadly: 5
        }
    }

    public static func < (lhs: LookalikeRisk, rhs: LookalikeRisk) -> Bool {
        lhs.severityRank < rhs.severityRank
    }
}

/// Something a species can be mistaken for, and the check that separates them.
public nonisolated struct Lookalike: Codable, Sendable, Hashable {
    public let name: String
    public let scientificName: String?
    public let risk: LookalikeRisk
    /// The specific, field-checkable difference — not a general warning.
    public let howToTell: String
    /// The catalogue page this card opens. Typed, so a lookalike can only name a species the
    /// catalogue has: an unknown id fails to decode, and the build fails with it.
    ///
    /// It is also where the card's photo comes from. A lookalike *is* a catalogue entry, so
    /// carrying a separate file name here could only ever duplicate or contradict that
    /// entry's own photos — and in practice it was never filled in, which is why every
    /// lookalike card rendered a placeholder.
    public let entry: SpeciesID

    public init(name: String, scientificName: String? = nil, risk: LookalikeRisk, howToTell: String, entry: SpeciesID) {
        self.name = name
        self.scientificName = scientificName
        self.risk = risk
        self.howToTell = howToTell
        self.entry = entry
    }
}
