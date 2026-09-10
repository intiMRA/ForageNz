import DesignLibrary
import SwiftUI

struct SafetyView: View {
    @Environment(SpeciesStore.self) private var store

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: .xSmall) {
                    Text("If you suspect poisoning")
                        .font(.headline)
                        .accessibilityIdentifier("safety.poisoningHeader")
                    Text("Call the National Poisons Centre on \(PoisonsCentre.displayNumber). Do not wait for symptoms — the most dangerous species in this guide have delayed onset.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let callURL = PoisonsCentre.callURL {
                        Link("Call \(PoisonsCentre.displayNumber)", destination: callURL)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.vertical, .xxSmall)
            }

            WhereYouAreSection()

            Section {
                ForEach(Self.groundRules, id: \.self) { rule in
                    Text(rule)
                        .font(.subheadline)
                }
            } header: {
                Text("Ground rules")
            }

            if !store.doNotEat.isEmpty {
                Section {
                    ForEach(store.doNotEat) { item in
                        NavigationLink(value: item) {
                            SpeciesRow(species: item)
                        }
                    }
                } header: {
                    Text("Learn these, then leave them alone")
                } footer: {
                    Text("These entries exist so you can recognise them in the field. None of them are food.")
                }
            }

            if !store.withDeadlyLookalikes.isEmpty {
                Section {
                    ForEach(store.withDeadlyLookalikes) { item in
                        NavigationLink(value: item) {
                            SpeciesRow(species: item)
                        }
                    }
                } header: {
                    Text("Edible, but has a deadly lookalike")
                } footer: {
                    Text("Read the lookalikes section on each of these before you harvest.")
                }
            }
        }
        .navigationTitle("Safety")
    }

    private static let groundRules = [
        "This app describes what to check. It cannot identify a plant for you, and a photo is not an identification.",
        "Never eat anything you have not confirmed with an experienced forager or a reliable field guide.",
        "Eat a small amount of anything new the first time, and only one new species at a time.",
        "Harvesting plant material on public conservation land needs a DOC permit. Most accessible native bush is DOC land.",
        "Check for a rāhui before gathering, especially on the coast. Respect it — it is there for a reason.",
        "Avoid roadside verges, railway corridors and council-maintained ground: they are routinely sprayed.",
        "Never harvest shellfish or seaweed without checking MPI's current biotoxin warnings for that stretch of coast."
    ]
}
