import DesignLibrary
import ForageCatalogue
import SwiftUI

struct SpeciesDetailView: View {
    let species: ForageSpecies

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .large) {
                header

                if species.caution == .doNotEat {
                    doNotEatBanner
                } else if species.highestLookalikeRisk == .deadly {
                    deadlyLookalikeBanner
                }

                section("Season", systemImage: "calendar") {
                    Text(species.seasonDescription)
                }

                section("Where to find it", systemImage: "map") {
                    Text(species.habitat)
                }

                section("How to identify it", systemImage: "magnifyingglass") {
                    Text(species.identification)
                }

                if species.caution != .doNotEat {
                    section("Edible parts", systemImage: "leaf") {
                        Text(species.edibleParts)
                    }

                    section("Preparation", systemImage: "frying.pan") {
                        Text(species.preparation)
                    }
                }

                if !species.lookalikes.isEmpty {
                    lookalikesSection
                }

                if !species.warnings.isEmpty {
                    warningsSection
                }

                if let ethics = species.harvestEthics {
                    section("Harvesting & tikanga", systemImage: "hands.sparkles") {
                        Text(ethics)
                    }
                }

                if species.isVerified {
                    section("Sources", systemImage: "book.closed") {
                        VStack(alignment: .leading, spacing: .xxSmall) {
                            ForEach(species.sources, id: \.self) { source in
                                Text(source)
                            }
                        }
                    }
                } else {
                    banner(
                        title: "Not yet checked",
                        message: "This entry has not been verified against a published field guide. Treat it as a starting point for your own identification, not an authority.",
                        tint: CautionLevel.careRequired.tintColor,
                        systemImage: "questionmark.circle.fill"
                    )
                }

                disclaimer
            }
            .padding(.all, .medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(species.commonName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: .xSmall) {
            Text(species.commonName)
                .font(.largeTitle.weight(.bold))

            if let maoriName = species.maoriName {
                Text(maoriName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text(species.scientificName)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)

            HStack(spacing: .xSmall) {
                CautionBadge(level: species.caution, showsFullLabel: true)

                Text(species.category.displayName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, .xSmall)
                    .padding(.vertical, .xxxSmall)
                    .background(.quaternary, in: Capsule())

                Text(species.origin.displayName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, .xSmall)
                    .padding(.vertical, .xxxSmall)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.top, .xxSmall)

            Text(species.summary)
                .font(.body)
                .padding(.top, .xxSmall)
        }
    }

    // MARK: - Banners

    private var doNotEatBanner: some View {
        banner(
            title: "Do not eat",
            message: "This entry is here so you can recognise this species and avoid it.",
            tint: CautionLevel.doNotEat.tintColor,
            systemImage: "xmark.octagon.fill"
        )
    }

    private var deadlyLookalikeBanner: some View {
        banner(
            title: "Has a deadly lookalike",
            message: "Read the lookalikes section below before you harvest this.",
            tint: LookalikeRisk.deadly.tintColor,
            systemImage: "exclamationmark.triangle.fill"
        )
    }

    private func banner(title: String, message: String, tint: Color, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: .small) {
            Image(systemName: systemImage)
                .imageScale(.large)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: .xxxSmall) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.all, .small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(Layout.bannerBackgroundOpacity), in: Layout.cardShape)
    }

    // MARK: - Sections

    private func section(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: .xSmall) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content()
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var lookalikesSection: some View {
        VStack(alignment: .leading, spacing: .small) {
            Label("Can be confused with", systemImage: "questionmark.circle")
                .font(.headline)

            ForEach(species.lookalikes) { lookalike in
                VStack(alignment: .leading, spacing: .xxxSmall) {
                    HStack(spacing: .xSmall) {
                        Text(lookalike.name)
                            .font(.subheadline.weight(.semibold))

                        Text(lookalike.risk.displayName)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, .xSmall)
                            .padding(.vertical, .xxxSmall)
                            .foregroundStyle(.white)
                            .background(lookalike.risk.tintColor, in: Capsule())
                    }

                    if let scientificName = lookalike.scientificName {
                        Text(scientificName)
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                    }

                    Text(lookalike.howToTell)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, .xxxSmall)
                }
                .padding(.all, .small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(Layout.cardBackgroundOpacity), in: Layout.cardShape)
            }
        }
    }

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: .xSmall) {
            Label("Safety", systemImage: "exclamationmark.shield")
                .font(.headline)

            ForEach(species.warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: .xSmall) {
                    Text("•")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text(warning)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var disclaimer: some View {
        Text(
            """
            This guide describes what to check — it cannot identify a plant for you. \
            Never eat anything you have not positively identified with an experienced \
            forager. If you suspect poisoning, call the National Poisons Centre on \
            \(PoisonsCentre.displayNumber).
            """
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.all, .small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(Layout.cardBackgroundOpacity), in: Layout.cardShape)
    }
}
