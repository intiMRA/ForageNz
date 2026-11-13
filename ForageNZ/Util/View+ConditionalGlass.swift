//
//  View+ConditionalGlass.swift
//  ForageNZ
//
//  Created by Inti Albuquerque on 14/11/2026.
//

import SwiftUI

extension View {
    /// Liquid Glass in `shape` on iOS 26, and `legacy` filling `shape` behind the view before
    /// it. For the controls and panels that float over content — not for content itself.
    /// `isInteractive` makes the glass react to touch, for a view that is itself tappable.
    @ViewBuilder
    func conditionalGlass<S: Shape, Legacy: ShapeStyle>(
        in shape: S,
        tint: Color? = nil,
        isInteractive: Bool = false,
        legacy: Legacy = .regularMaterial
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(Self.glass(tint: tint, isInteractive: isInteractive), in: shape)
        } else {
            self.background(legacy, in: shape)
        }
    }

    @available(iOS 26.0, *)
    private static func glass(tint: Color?, isInteractive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        if isInteractive {
            glass = glass.interactive()
        }
        return glass
    }
}
