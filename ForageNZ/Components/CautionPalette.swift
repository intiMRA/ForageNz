import SwiftUI

/// Where a caution colour is being used. A badge is a small shape found at a glance; a card is
/// a large one the reader looks *through* at the text on top — so the two want different
/// strengths and different directions, and fixing both per role stops either being decided at a
/// call site.
///
/// Only a ramp consults this. A flat colour is drawn exactly as its colourist drew it.
enum CautionRole {
    case badge
    case card

    /// Dark mode takes more of the ramp in both roles: the same colour separates less from
    /// near-black than from near-white.
    func opacity(in scheme: ColorScheme) -> Double {
        switch (self, scheme) {
        case (.badge, .dark): 0.7
        case (.badge, _): 0.4
        case (.card, .dark): 0.5
        case (.card, _): 0.2
        }
    }

    /// A slab is tall enough to show a ramp down it, and vertical keeps a list reading as one
    /// column. A capsule is far wider than it is tall, where only a diagonal shows the middle
    /// stops of a three-stop ramp at all.
    var start: UnitPoint { self == .card ? .top : .topLeading }
    var end: UnitPoint { self == .card ? .bottom : .bottomTrailing }
}

/// What fills a caution affordance — a card's slab or a badge's capsule.
///
/// Two cases, because one of them has to be *drawn* differently and that difference is worth
/// naming rather than hiding behind a boolean. Everything but `psychoactive` is a `.tint`, and a
/// `.tint` renders exactly as it always has: the colour as drawn, at full strength, wherever it
/// is used. The role-based dimming below applies to the ramp and to nothing else.
///
/// Lives here rather than beside `SpeciesCard` because this file compiles into the editor too,
/// and the card does not.
enum CardFill {
    /// A single colour, carrying whatever alpha its colourist chose.
    case tint(Color)

    /// A ramp, dimmed per role — and, on a card, drawn over an opaque base. See `SpeciesCard`.
    case ramp(Gradient)

    func style(_ role: CautionRole, in scheme: ColorScheme) -> AnyShapeStyle {
        switch self {
        case .tint(let color):
            return AnyShapeStyle(color)
        case .ramp(let gradient):
            let opacity = role.opacity(in: scheme)
            let dimmed = Gradient(
                stops: gradient.stops.map {
                    Gradient.Stop(color: $0.color.opacity(opacity), location: $0.location)
                }
            )
            return AnyShapeStyle(
                LinearGradient(gradient: dimmed, startPoint: role.start, endPoint: role.end)
            )
        }
    }
}

/// The single mapping from safety semantics to colour. Colouring a caution affordance
/// ad hoc at a call site is what this exists to prevent.
extension CautionLevel {
    /// What a badge of this caution is filled with. The three flat cases are the solid colours
    /// they have always been — only `psychoactive` ramps, and only it is ever dimmed.
    var tintColor: CardFill {
        switch self {
        case .straightforward:
            return .tint(Color(.cautionSafe))
        case .careRequired:
            return .tint(Color(.cautionCare))
        case .doNotEat:
            return .tint(Color(.cautionDanger))
        case .psychoactive:
            return .ramp(.init(colors: [Color(.psychoGradient1), Color(.psychoGradient2), Color(.psychoGradient3)]))
        }
    }

    /// White on the three solid caution colours, as it has always been. The psychoactive badge
    /// is the ramp at 40% in light mode — pale enough that white on it is unreadable — so it
    /// takes `.primary`, which is also what the owner's mock shows.
    var badgeForeground: Color {
        switch self {
        case .straightforward, .careRequired, .doNotEat: .white
        case .psychoactive: .primary
        }
    }

    /// The slab a list row sits on. Only the two cases the reader may not take colour it —
    /// if every row were tinted, the tint would stop meaning anything.
    ///
    /// Three of the four have a drawn colour that is already the strength it should be, so they
    /// stay flat `.tint`s and render exactly as they always have.
    var rowBackground: CardFill {
        switch self {
        case .straightforward, .careRequired:
            return .tint(Color(.rowCardBackground))
        case .doNotEat:
            return .tint(Color(.riskDeadlyBackground))
        // The only case with no drawn background, because it is the only ramp. The card role's
        // opacity is what stands in for the colourist's alpha on the hand-picked sets.
        case .psychoactive:
            return tintColor
        }
    }
}

extension LookalikeRisk {
    /// As on `CautionLevel`: four solid colours unchanged, one ramp.
    var tintColor: CardFill {
        switch self {
        case .edible:
            return .tint(Color(.riskEdible))
        // Shares the caution palette's purple rather than owning a second one: the two
        // enums are making the same claim from opposite sides of the same card.
        case .psychoactive:
            return CautionLevel.psychoactive.tintColor
        case .unpalatable:
            return .tint(Color(.riskUnpalatable))
        case .toxic:
            return .tint(Color(.riskToxic))
        case .deadly:
            return .tint(Color(.riskDeadly))
        // A grey, and deliberately the one colour on the palette that is not on the red-to-
        // green scale at all: "not known" has to be legible as a claim the catalogue is
        // declining to make, not as a severity sitting between psychoactive and toxic.
        case .unknown:
            return .tint(Color(.riskUnknown))
        }
    }

    /// See `CautionLevel.badgeForeground` — white on the five solid risks, `.primary` on the
    /// pale psychoactive ramp.
    var badgeForeground: Color {
        switch self {
        case .edible, .unpalatable, .toxic, .deadly, .unknown: .white
        case .psychoactive: .primary
        }
    }

    /// Every lookalike card is tinted, unlike a species row where a neutral slab is the
    /// default.
    ///
    /// Five of the six have their own drawn background, carrying an alpha chosen per case
    /// (0.5 for toxic, 0.8 for unpalatable, 0.7/0.6 for deadly, 0.8/0.5 for unknown) — and
    /// `riskEdibleBackground` is not the foreground colour at all but a muted sage. Deriving
    /// these from `tintColor` would flatten all of that to one number and change the edible
    /// card's hue outright.
    var background: CardFill {
        switch self {
        case .edible:
            return .tint(Color(.riskEdibleBackground))
        case .unpalatable:
            return .tint(Color(.riskUnpalatableBackground))
        case .toxic:
            return .tint(Color(.riskToxicBackground))
        case .deadly:
            return .tint(Color(.riskDeadlyBackground))
        // The one case with no drawn background: it is a three-stop ramp, so its slab is the
        // ramp at card strength instead.
        case .psychoactive:
            return tintColor
        case .unknown:
            return .tint(Color(.riskUnknownBackground))
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
