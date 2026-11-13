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
        VStack(alignment: .leading, spacing: .xSmall) {
            if let id = pin.speciesID, let model = models.createListingRowModel(id: id) {
                Button {
                    router.push(.species(id))
                } label: {
                    SpeciesRow(model: model)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("findCard")
            } else {
                Text("No longer in the guide")
                    .font(.headline)
            }

            HStack {
                Text("Found \(pin.foundAt.formatted(date: .numeric, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Delete", role: .destructive) {
                    confirmsDelete = true
                }
                .confirmationDialog("Delete this find?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                    Button("Delete", role: .destructive, action: onDelete)
                }
            }
        }
        .padding(.all, .small)
        .background(.regularMaterial, in: Layout.cardShape)
        .padding(.all, .medium)
    }
}

/// A find on the map, drawn with its species' group.
struct FindPinView: View {
    let group: ForageGroup?
    let isSelected: Bool

    var body: some View {
        icon
            .padding(.all, .xSmall)
            .background(.regularMaterial, in: Circle())
            .overlay {
                Circle().strokeBorder(.tint, lineWidth: Layout.findPinBorderWidth)
            }
            .scaleEffect(isSelected ? Layout.selectedFindPinScale : 1)
            .animation(.snappy, value: isSelected)
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
