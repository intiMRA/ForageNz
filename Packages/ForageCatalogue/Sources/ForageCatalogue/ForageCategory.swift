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
    case native
    case introduced
    case pest

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .native: "Native"
        case .introduced: "Introduced"
        case .pest: "Weed / pest"
        }
    }

    public var harvestGuidance: String {
        switch self {
        case .native: "Take sparingly. A DOC permit is required on conservation land."
        case .introduced: "Naturalised and not a pest. Harvest reasonably."
        case .pest: "A weed. Harvest as much as you like — you are helping."
        }
    }

    public var symbolName: String {
        switch self {
        case .native: "leaf.fill"
        case .introduced: "globe"
        case .pest: "scissors"
        }
    }
}
