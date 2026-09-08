import DesignLibrary
import ForageCatalogue
import SwiftUI

struct CautionBadge: View {
    let level: CautionLevel
    var showsFullLabel: Bool = false

    var body: some View {
        HStack(spacing: .xxxSmall) {
            Image(systemName: level.symbolName)
                .imageScale(.small)
            Text(showsFullLabel ? level.displayName : level.shortLabel)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, .xSmall)
        .padding(.vertical, .xxxSmall)
        .foregroundStyle(.white)
        .background(level.tintColor, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(level.displayName)
    }
}

#Preview {
    VStack(spacing: .small) {
        CautionBadge(level: .straightforward)
        CautionBadge(level: .careRequired, showsFullLabel: true)
        CautionBadge(level: .doNotEat, showsFullLabel: true)
    }
    .padding(.all, .medium)
}
