import Foundation

/// How much care a species demands before anything goes in a basket.
///
/// This is deliberately the most prominent attribute in the UI. The app never asserts
/// that a plant in front of the user *is* a given species — it describes what to check.
public nonisolated enum CautionLevel: String, Codable, Sendable {
    /// Distinctive enough that a careful beginner can identify it, and harmless if they get it wrong.
    case straightforward
    /// Has toxic lookalikes, or needs processing/cooking before it is safe.
    case careRequired
    /// Listed so it can be recognised and avoided. Never eat.
    case doNotEat

    public var displayName: String {
        switch self {
        case .straightforward: "Straightforward"
        case .careRequired: "Care required"
        case .doNotEat: "Do not eat"
        }
    }

    public var shortLabel: String {
        switch self {
        case .straightforward: "OK"
        case .careRequired: "Care"
        case .doNotEat: "Toxic"
        }
    }

    public var symbolName: String {
        switch self {
        case .straightforward: "checkmark.seal"
        case .careRequired: "exclamationmark.triangle"
        case .doNotEat: "xmark.octagon"
        }
    }
}

/// How bad it is to confuse a species with one of its lookalikes.
public nonisolated enum LookalikeRisk: String, Codable, Sendable, Comparable {
    case deadly
    /// Will make you seriously unwell.
    case toxic
    case unpalatable

    public var displayName: String {
        switch self {
        case .deadly: "Deadly"
        case .toxic: "Toxic"
        case .unpalatable: "Unpalatable"
        }
    }

    private var severityRank: Int {
        switch self {
        case .unpalatable: 0
        case .toxic: 1
        case .deadly: 2
        }
    }

    public static func < (lhs: LookalikeRisk, rhs: LookalikeRisk) -> Bool {
        lhs.severityRank < rhs.severityRank
    }
}

/// Something a species can be mistaken for, and the check that separates them.
public nonisolated struct Lookalike: Codable, Sendable, Hashable, Identifiable {
    public let name: String
    public let scientificName: String?
    public let risk: LookalikeRisk
    /// The specific, field-checkable difference — not a general warning.
    public let howToTell: String

    public var id: String { name }

    public init(name: String, scientificName: String? = nil, risk: LookalikeRisk, howToTell: String) {
        self.name = name
        self.scientificName = scientificName
        self.risk = risk
        self.howToTell = howToTell
    }
}
