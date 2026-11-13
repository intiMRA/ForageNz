import DesignLibrary
import SwiftUI

/// The card over the bottom of the map for the selected find. Tapping the species opens its page.
struct FindCard: View {
    let pin: FindPinModel
    let onDelete: () -> Void

    @Environment(\.speciesModels) private var models
    @Environment(\.router) private var router

    @State private var confirmsDelete = false

    var body: some View {
        Group {
            if let id = pin.speciesID, let model = models.createListingRowModel(id: id) {
                // A tap on the card rather than a `Button` around it: a control inside a
                // button's label gets the button's tap, and the delete button lives inside.
                // The row's `Spacer`s take every point they are offered, and a safe-area inset
                // offers the whole screen; pinning to the ideal height makes it the list's card.
                SpeciesRow(model: model) {
                    foundDate
                } besideBadge: {
                    deleteButton
                }
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture { router.push(.species(id)) }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { router.push(.species(id)) }
                .accessibilityIdentifier("findCard")
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: .xxSmall) {
                        Text("No longer in the guide")
                            .font(.headline)
                        foundDate
                    }
                    Spacer()
                    deleteButton
                }
                .padding(.all, .small)
                .conditionalGlass(in: Layout.cardShape)
            }
        }
        .padding(.all, .medium)
    }

    private var foundDate: some View {
        Text("Found \(pin.foundAt.formatted(date: .numeric, time: .omitted))")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private var deleteButton: some View {
        Button {
            confirmsDelete = true
        } label: {
            Image(systemName: "xmark.circle.fill")
                .icon(size: .standard, color: .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete")
        .confirmationDialog("Delete this find?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

/// A find on the map: its species' group on the same colour as its species' card.
struct FindPinView: View {
    let group: ForageGroup?
    let caution: CautionLevel?
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        icon
            .padding(.all, .xxSmall)
            .background { background }
            .compositingGroup()
            .shadow(color: .shadow, radius: Layout.findPinShadowRadius)
            .scaleEffect(isSelected ? Layout.selectedFindPinScale : 1)
            .animation(.snappy, value: isSelected)
    }

    /// Opaque, unlike the card: the list's backdrop goes under the card's fill, as
    /// `SpeciesCard` does for its ramp, so the map never shows through.
    private var background: some View {
        Circle()
            .fill(Color(uiColor: .systemGroupedBackground))
            .overlay {
                if let caution {
                    Circle().fill(caution.rowBackground.style(.card, in: colorScheme))
                }
            }
    }

    @ViewBuilder
    private var icon: some View {
        if let group {
            group.image.icon(size: .standard, color: .primary)
        } else {
            Image(systemName: "questionmark").icon(size: .standard, color: .secondary)
        }
    }
}
