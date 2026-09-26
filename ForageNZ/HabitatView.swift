//
//  HabitatView.swift
//  ForageNZ
//
//  Created by Inti Albuquerque on 25/09/2026.
//

import Foundation
import SwiftUI
import DesignLibrary

struct HabitatView: View {
    let habitats: [Habitat]
    let layoutDirection: LayoutDirection
    var icon: Image?
    var includeName: Bool = false
    
    var body: some View {
        if !habitats.isEmpty {
            VStack(alignment: .leading, spacing: .xxxSmall) {
                if let icon {
                    HStack(spacing: .xxSmall) {
                        icon
                            .icon(size: .small, color: .primary)
                        Text("Habitat:")
                            .bold()
                            .font(.caption)
                    }
                }
                else {
                    Text("Habitat:")
                        .bold()
                        .font(.footnote)
                }
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
