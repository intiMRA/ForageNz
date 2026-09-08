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
