//
//  HabitatView.swift
//  ForageNZ
//
//  Created by Inti Albuquerque on 25/09/2026.
//

import Foundation
import SwiftUI
import DesignLibrary

/// The classification icons for one entry's habitats, and optionally their names.
///
/// It draws no title of its own. Each caller owns its heading, because the two disagree about
/// what a heading is — the species row wants "Habitat:" in the same footnote style as its
/// "Group:" and "Season:" siblings, the detail page wants a `createSectionHeader` matching its
/// other sections. Keeping the title here meant the detail page could not draw one for an
/// entry with no classified habitats, since this view renders nothing at all in that case.
struct HabitatView: View {
    let habitats: [Habitat]
    let layoutDirection: LayoutDirection
    var includeName: Bool = false

    var body: some View {
        if !habitats.isEmpty {
            VStack(alignment: .leading, spacing: .xxxSmall) {
                LazyVGrid(columns: [
                    .init(.fixed(IconSize.standard.value())),
                    .init(.fixed(IconSize.standard.value())),
                    .init(.fixed(IconSize.standard.value()))], alignment: .trailing) {
                        ForEach(habitats) { habitat in
                            habitat.image
                                .icon(size: .standard, color: .primary)
                        }
                    }
                    .environment(\.layoutDirection, layoutDirection)
                    .fixedSize()
                
                if includeName {
                    Text(habitats.map { String(localized: $0.displayName) }.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
