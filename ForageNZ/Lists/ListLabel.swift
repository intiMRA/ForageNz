import SwiftUI

/// A list's name, with its icon when the user picked one.
struct ListLabel: View {
    let list: SpeciesListSnapshot

    var body: some View {
        if let symbolName = list.symbolName {
            Label(list.name, systemImage: symbolName)
        } else {
            Text(list.name)
        }
    }
}
