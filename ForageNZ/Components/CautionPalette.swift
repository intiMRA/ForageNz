import SwiftUI

/// The single mapping from safety semantics to colour. Colouring a caution affordance
/// ad hoc at a call site is what this exists to prevent.
extension CautionLevel {
    var tintColor: Color {
        switch self {
        case .straightforward: Color(.cautionSafe)
        case .careRequired: Color(.cautionCare)
        case .doNotEat: Color(.cautionDanger)
        case .psychoactive: Color(.cautionPsychoactive)
        }
    }

    /// The slab a list row sits on. Only the two cases the reader may not take colour it —
    /// if every row were tinted, the tint would stop meaning anything.
    var rowBackgroundColor: Color {
        switch self {
        case .straightforward, .careRequired: Color(.rowCardBackground)
        case .doNotEat: Color(.riskDeadlyBackground)
        case .psychoactive: Color(.cautionPsychoactiveBackground)
        }
    }
}

extension LookalikeRisk {
    var tintColor: Color {
        switch self {
        case .edible: Color(.riskEdible)
        case .psychoactive: Color(.cautionPsychoactive)
        case .unpalatable: Color(.riskUnpalatable)
        case .toxic: Color(.riskToxic)
        case .deadly: Color(.riskDeadly)
        }
    }

    var backgroundColor: Color {
        switch self {
        case .edible:
            Color(.riskEdibleBackground)
        // Shares the caution palette's purple rather than owning a second one: the two
        // enums are making the same claim from opposite sides of the same card.
        case .psychoactive:
            Color(.cautionPsychoactiveBackground)
        case .unpalatable:
            Color(.riskUnpalatableBackground)
        case .toxic:
            Color(.riskToxicBackground)
        case .deadly:
            Color(.riskDeadlyBackground)
        }
    }
}

extension LandStatus {
    /// Note what is missing: no `cautionSafe`. Green here would read as "you may harvest",
    /// and this map only knows about two restrictions — it says nothing about private land,
    /// a rāhui, or a regional bylaw. Nothing recorded is the absence of an answer, not a yes.
    var tintColor: Color {
        if contains(.marineReserve) { return Color(.cautionDanger) }
        if contains(.conservation) { return Color(.cautionCare) }
        return .secondary
    }

    var symbolName: String {
        if contains(.marineReserve) { return "hand.raised.fill" }
        if contains(.conservation) { return "leaf.fill" }
        return "mappin.and.ellipse"
    }
}
