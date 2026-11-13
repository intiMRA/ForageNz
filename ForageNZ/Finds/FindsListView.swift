import SwiftUI

/// The finds as a list, newest first: readable when the map tiles cannot load.
struct FindsListView: View {
    let pins: [FindPinModel]
    let onDelete: (FindPinModel.ID) -> Void

    @Environment(\.router) private var router

    var body: some View {
        if pins.isEmpty {
            ContentUnavailableView(
                "No finds yet",
                systemImage: "mappin.slash",
                description: Text("Save where you found a species from the map.")
            )
        } else {
            List(pins.reversed()) { pin in
                Button {
                    guard let id = pin.speciesID else { return }
                    router.push(.species(id))
                } label: {
                    VStack(alignment: .leading) {
                        Text(pin.commonName ?? String(localized: "No longer in the guide"))
                            .font(.headline)
                        Text(pin.foundAt.formatted(date: .numeric, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(coordinateText(pin.coordinate))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(pin.speciesID == nil)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        onDelete(pin.id)
                    }
                }
            }
        }
    }

    private func coordinateText(_ coordinate: Coordinate) -> String {
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(5))
        return "\(coordinate.latitude.formatted(style)), \(coordinate.longitude.formatted(style))"
    }
}
