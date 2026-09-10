import DesignLibrary
import ForageCatalogue
import SwiftUI

/// Every string in here is deliberately hedged. The map is good enough to tell someone to
/// stop and check, and not good enough to tell them anything is allowed — so no state of
/// this view ever says yes.
struct WhereYouAreSection: View {
    @Environment(WhereYouAreStore.self) private var store

    var body: some View {
        Section {
            switch store.state {
            case .idle:
                checkButton(title: "Check where I am")
            case .checking:
                HStack(spacing: .xSmall) {
                    ProgressView()
                    Text("Getting a fix…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            case .read(let reading):
                ForEach(Self.verdicts(for: reading), id: \.title) { verdict in
                    VerdictRow(verdict: verdict)
                }
                checkButton(title: "Check again")
            case .failed(let message):
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                checkButton(title: "Try again")
            }
        } header: {
            Text("Where you are")
        } footer: {
            Text("Works offline. Boundaries are DOC's, generalised to about \(LandStatusMap.approximateResolutionMetres) m — a prompt to check, never a legal answer. Private land, rāhui and council bylaws are not in this map.")
        }
    }

    private func checkButton(title: String) -> some View {
        Button(title) {
            Task { await store.check() }
        }
        .font(.subheadline.weight(.semibold))
        .disabled(store.isChecking)
    }
}

// MARK: - Verdicts

extension WhereYouAreSection {
    struct Verdict: Equatable {
        let symbolName: String
        let tint: Color
        let title: String
        let detail: String
    }

    /// A reading can carry both flags at once, so this returns a list rather than one answer.
    static func verdicts(for reading: WhereYouAreStore.Reading) -> [Verdict] {
        guard case .inside(let status) = reading else {
            return [
                Verdict(
                    symbolName: "globe",
                    tint: .secondary,
                    title: "Outside the map",
                    detail: "This map covers New Zealand only."
                )
            ]
        }

        var verdicts: [Verdict] = []
        if status.contains(.marineReserve) {
            verdicts.append(
                Verdict(
                    symbolName: LandStatus.marineReserve.symbolName,
                    tint: LandStatus.marineReserve.tintColor,
                    title: "Probably a marine reserve",
                    detail: "Taking anything is prohibited here — seaweed and shellfish included. No permit covers it."
                )
            )
        }
        if status.contains(.conservation) {
            verdicts.append(
                Verdict(
                    symbolName: LandStatus.conservation.symbolName,
                    tint: LandStatus.conservation.tintColor,
                    title: "Probably conservation land",
                    detail: "Harvesting plant material on DOC land needs a permit. Confirm the boundary before you pick."
                )
            )
        }
        guard verdicts.isEmpty else { return verdicts }

        return [
            Verdict(
                symbolName: LandStatus().symbolName,
                tint: LandStatus().tintColor,
                title: "Nothing recorded here",
                detail: "No conservation land or marine reserve within about \(LandStatusMap.approximateResolutionMetres) m. That is not permission to harvest — check who owns the ground."
            )
        ]
    }

    struct VerdictRow: View {
        let verdict: Verdict

        var body: some View {
            HStack(alignment: .top, spacing: .small) {
                Image(systemName: verdict.symbolName)
                    .imageScale(.large)
                    .foregroundStyle(verdict.tint)
                    .frame(width: Layout.rowIconWidth)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: .xxSmall) {
                    Text(verdict.title)
                        .font(.headline)
                    Text(verdict.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, .xxSmall)
        }
    }
}
