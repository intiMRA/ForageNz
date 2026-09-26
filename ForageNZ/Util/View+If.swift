//
//  View+If.swift
//  ForageNZ
//
//  Created by Inti Albuquerque on 23/09/2026.
//

import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

import SwiftUI

extension View {
    @ViewBuilder
    func conditionalGlass(tint: Color? = nil, legacyColor: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self
                    .glassEffect(.regular.tint(tint))
            }
            else {
                self
                    .glassEffect()
            }
        } else {
            if let legacyColor {
                self
                    .background(legacyColor)
            }
            else {
                self
            }
        }
    }
}

extension View where Self: Shape {
    @ViewBuilder
    func conditionalGlassShape(tint: Color? = nil, legacyColor: Color? = nil, stroke: CGFloat = 0, strokeColor: Color = .accent) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self
                    .stroke(strokeColor, lineWidth: stroke)
                    .glassEffect(.regular.tint(tint), in: self)
            }
            else {
                self
                    .stroke(strokeColor, lineWidth: stroke)
                    .glassEffect()
            }
        } else {
            if let legacyColor {
                self
                    .stroke(strokeColor, lineWidth: stroke)
                    .fill(legacyColor)
            }
            else {
                self
                    .stroke(strokeColor, lineWidth: stroke)
            }
        }
    }
}

