import ForageCatalogue
import SwiftUI

/// The single mapping from safety semantics to colour. Colouring a caution affordance
/// ad hoc at a call site is what this exists to prevent.
extension CautionLevel {
    var tintColor: Color {
        switch self {
        case .straightforward: Color(.cautionSafe)
        case .careRequired: Color(.cautionCare)
        case .doNotEat: Color(.cautionDanger)
        }
    }
}

extension LookalikeRisk {
    var tintColor: Color {
        switch self {
        case .unpalatable: Color(.cautionSafe)
        case .toxic: Color(.cautionCare)
        case .deadly: Color(.cautionDanger)
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
