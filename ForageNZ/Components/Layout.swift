import DesignLibrary
import SwiftUI

/// Layout values that have no DesignLibrary token.
enum Layout {
    static let cardCornerRadius: CGFloat = 12

    /// Width of the leading icon gutter in a species row, so names align down the list.
    static let rowIconWidth: CGFloat = 28

    /// The drawn classification artwork inside a chip. The art is 24pt, sized for the row
    /// gutter; a chip sits at caption size and needs it brought down to the text.
    static let chipIconSize: CGFloat = 14

    static let bannerBackgroundOpacity: Double = 0.12

    static let cardBackgroundOpacity: Double = 0.4

    /// Identification photo card. Wide enough to show a leaf margin, short enough that
    /// several fit on screen at once.
    static let photoWidth: CGFloat = CommonSizes.large.rawValue
    static let photoHeight: CGFloat = 150

    static var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardCornerRadius)
    }

    /// List cards — a species row and a lookalike card — are drawn tighter than a photo or a
    /// banner. Kept distinct from `cardCornerRadius` rather than unified, because the two
    /// radii were chosen against different content.
    static let rowCardCornerRadius: CGFloat = 8

    static var rowCardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: rowCardCornerRadius)
    }

    /// The square thumbnail on a list card.
    static let thumbnailSize: CGFloat = 100

    /// Drop shadow shared by every list card.
    static let cardShadowRadius: CGFloat = 2
}
