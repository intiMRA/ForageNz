import SwiftUINavigation

/// Everywhere a screen in this app can go.
///
/// One named route type rather than pushing bare values, so a second kind of page is a case
/// here — not a second `navigationDestination` somewhere else. `SpeciesDestination` switches
/// over it exhaustively, which means adding a case is a compile error at the one place that
/// has to handle it.
@CasePathable
enum Destination: Hashable {
    case species(SpeciesID)
}
