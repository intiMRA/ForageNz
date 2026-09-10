import SwiftUI

/// Layout values the editor needs that the app's `Layout` does not have — macOS inset
/// controls are smaller than iOS cards, and the window has dimensions the phone never will.
///
/// Shared values stay in `Layout` (opacities, card shape, photo card size); caution colour
/// stays in `CautionPalette`. Only what is genuinely editor-only lives here.
enum EditorLayout {
    /// Inset panels and thumbnails. Smaller than `Layout.cardCornerRadius` on purpose: at
    /// 12 pt a macOS text-field group reads as a floating card rather than a grouped inset.
    static let insetCornerRadius: CGFloat = 6

    static var insetShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: insetCornerRadius)
    }

    static let thumbnailSize: CGFloat = 96

    static let windowMinimum = CGSize(width: 900, height: 600)
    static let sidebarMinimumWidth: CGFloat = 260
    static let addSheetWidth: CGFloat = 420
    static let riskPickerWidth: CGFloat = 140
    static let monthButtonMinimumWidth: CGFloat = 26

    /// The "edited, not saved" marker in the sidebar.
    static let editedDotSize: CGFloat = 7

    /// A selected month in the picker. Stronger than a background tint, weaker than a fill.
    static let selectedTintOpacity: Double = 0.3
}
