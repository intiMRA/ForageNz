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

    public var displayName: LocalizedStringResource {
        switch self {
        case .straightforward: "Straightforward"
        case .careRequired: "Care required"
        case .doNotEat: "Do not eat"
        }
    }

    public var shortLabel: LocalizedStringResource {
        switch self {
        case .straightforward: "OK"
        case .careRequired: "Care"
        case .doNotEat: "Toxic"
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
    /// The safe member of the pair: no worse than the entry it is carded against, and
    /// usually the one the forager was looking for. Not a claim that it needs no care —
    /// that is its own entry's `caution` to state.
    case edible

    public var displayName: LocalizedStringResource {
        switch self {
        case .deadly: "Deadly"
        case .toxic: "Toxic"
        case .unpalatable: "Unpalatable"
        case .edible: "Edible"
        }
    }

    private var severityRank: Int {
        switch self {
        case .edible: 0
        case .unpalatable: 1
        case .toxic: 2
        case .deadly: 3
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
