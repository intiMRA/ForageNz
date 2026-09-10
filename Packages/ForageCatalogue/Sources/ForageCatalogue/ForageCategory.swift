import Foundation

public nonisolated enum ForageCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case greens
    case herbs
    case fruit
    case fungi
    case seaweed
    case nuts

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .greens: "Greens & leaves"
        case .herbs: "Herbs & flavour"
        case .fruit: "Fruit & berries"
        case .fungi: "Fungi"
        case .seaweed: "Seaweed"
        case .nuts: "Nuts & seeds"
        }
    }

    public var symbolName: String {
        switch self {
        case .greens: "leaf"
        case .herbs: "camera.macro"
        case .fruit: "apple.logo"
        case .fungi: "umbrella"
        case .seaweed: "water.waves"
        case .nuts: "circle.grid.2x1.fill"
        }
    }
}

/// Where a species sits relative to Aotearoa's own flora — which drives how
/// freely it can be harvested.
public nonisolated enum ForageOrigin: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Occurs naturally in Aotearoa and nowhere else on Earth.
    case endemic
    /// Occurs naturally here, and elsewhere too.
    case native
    case introduced
    case pest

    public var id: String { rawValue }

    /// Endemic and native together: the species that belong here, carry tikanga, and need
    /// a permit on conservation land. Kept as one predicate so the two cannot drift apart
    /// in the validation rules and the editor.
    public var isIndigenous: Bool {
        switch self {
        case .endemic, .native: true
        case .introduced, .pest: false
        }
    }

    public var displayName: String {
        switch self {
        case .endemic: "Endemic"
        case .native: "Native"
        case .introduced: "Introduced"
        case .pest: "Weed / pest"
        }
    }

    public var harvestGuidance: String {
        switch self {
        case .endemic: "Found nowhere else on Earth. Take the least you need. A DOC permit is required on conservation land."
        case .native: "Take sparingly. A DOC permit is required on conservation land."
        case .introduced: "Naturalised and not a pest. Harvest reasonably."
        case .pest: "A weed. Harvest as much as you like — you are helping."
        }
    }

    public var symbolName: String {
        switch self {
        case .endemic: "leaf.circle.fill"
        case .native: "leaf.fill"
        case .introduced: "globe"
        case .pest: "scissors"
        }
    }
}
