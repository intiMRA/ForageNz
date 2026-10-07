import DesignLibrary
import SwiftUI

/// Marks a piece of UI that works but has never been designed.
///
/// The owner designs this app; a view built without them wearing its own look is a decision
/// nobody made, and once it ships it reads as settled. So anything added to the interface
/// that the owner has not drawn or asked for is painted bright magenta until they have: a
/// colour chosen because it cannot be mistaken for a considered one, identical in light and
/// dark so neither appearance lets it pass.
///
/// `grep -rn "needsDesign" ForageNZ` is the complete list of what is outstanding — which is
/// the other half of the point. A placeholder that cannot be enumerated is a placeholder that
/// stays.
extension View {
    func needsDesign() -> some View {
        padding(.all, .xSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.needsDesign), in: .rect(cornerRadius: 6))
    }
}
