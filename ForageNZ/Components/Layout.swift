import DesignLibrary
import SwiftUI

/// Layout values that have no DesignLibrary token.
enum Layout {
    static let cardCornerRadius: CGFloat = 12

    /// Width of the leading icon gutter in a species row, so names align down the list.
    static let rowIconWidth: CGFloat = 28

    static let bannerBackgroundOpacity: Double = 0.12

    static let cardBackgroundOpacity: Double = 0.4

    /// Identification photo card. Wide enough to show a leaf margin, short enough that
    /// several fit on screen at once.
    static let photoWidth: CGFloat = CommonSizes.large.rawValue
    static let photoHeight: CGFloat = 150

    static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardCornerRadius)
    }
}
