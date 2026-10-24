import DesignLibrary
import SwiftUI

struct SafetyView: View {
    @Environment(SpeciesStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .small) {
                poisoning

                whereYouAre

                groundRules

                CollapsibleSpeciesList(accessibilityIDPrefix: "safety.doNotEat", title: "Do not eat", species: store.doNotEat)

                CollapsibleSpeciesList(accessibilityIDPrefix: "safety.psychoactive", title: "Psychoactive", species: store.psychoactive)

                CollapsibleSpeciesList(accessibilityIDPrefix: "safety.deadlyLookalikes", title: "Has deadly lookalikes", species: store.withDeadlyLookalikes)
            }
            .padding(.horizontal, .medium)
        }
        .navigationTitle("Safety")
    }

    private var poisoning: some View {
        VStack(alignment: .leading, spacing: .xxSmall) {
            makeHeader(image: Image(.outlineExclamation), title: "If you suspect poisoning")
                .accessibilityIdentifier("safety.poisoningHeader")

            Text(Self.poisoningAdvice)
                .font(.callout)
                .italic()
                .foregroundStyle(.secondary)
            if let callURL = PoisonsCentre.callURL {
                Link("Call \(PoisonsCentre.displayNumber)", destination: callURL)
                    .font(.callout.weight(.semibold))
            }
        }
    }

    private var groundRules: some View {
        VStack(alignment: .leading) {
            makeHeader(image: Image(.outlineQuestion), title: "Ground rules")

            ForEach(Self.groundRuleLines, id: \.self) { rule in
                Text(rule)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }

    private var whereYouAre: some View {
        VStack(alignment: .leading) {
            makeHeader(image: Image(systemName: "mappin.and.ellipse.circle.fill"), title: "Where you are")

            WhereYouAreSection()
        }
    }

    private func makeHeader(image: Image, title: LocalizedStringKey) -> some View {
        HStack(spacing: .xxSmall) {
            image
                .icon(size: .small, color: .primary)

            Text(title)
                .font(.title3)
                .bold()
        }
    }

    /// One localised sentence with a link run on the number, rather than markdown: the `tel:`
    /// address comes from `PoisonsCentre`, and a link target interpolated into a
    /// `LocalizedStringKey` is not parsed as markdown.
    static var poisoningAdvice: AttributedString {
        var advice = AttributedString(localized: "Call the National Poisons Centre on \(PoisonsCentre.displayNumber). Do not wait for symptoms — the most dangerous species in this guide have delayed onset.")
        if let callURL = PoisonsCentre.callURL,
           let number = advice.range(of: PoisonsCentre.displayNumber) {
            advice[number].link = callURL
        }
        return advice
    }

    private static let groundRuleLines = [
        "This app describes what to check. It cannot identify a plant for you, and a photo is not an identification.",
        "Never eat anything you have not confirmed with an experienced forager or a reliable field guide.",
        "Eat a small amount of anything new the first time, and only one new species at a time.",
        "Harvesting plant material on public conservation land needs a DOC permit. Most accessible native bush is DOC land.",
        "Check for a rāhui before gathering, especially on the coast. Respect it — it is there for a reason.",
        "Avoid roadside verges, railway corridors and council-maintained ground: they are routinely sprayed.",
        "Never harvest shellfish or seaweed without checking MPI's current biotoxin warnings for that stretch of coast."
    ]
}

private struct CollapsibleSpeciesList: View {
    let accessibilityIDPrefix: String
    let title: LocalizedStringKey
    let species: [ForageSpecies]
    @State private var isExpanded = false

    var body: some View {
        if !species.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(species) { item in
                    SpeciesRowButton(species: item)
                }
            } label: {
                Text(title)
                    .font(.title3)
                    .bold()
            }
            .accessibilityIdentifier("\(accessibilityIDPrefix).toggle")
        }
    }
}
