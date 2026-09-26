import DesignLibrary
import SwiftUI

struct SpeciesDetailView: View {
    let model: InfoPageModel
    
    private var species: ForageSpecies { model.species }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .medium) {
                header
                
                description
                
                habitat
                
                howToFindIt
                
                if species.caution != .doNotEat {
                    edibleParts
                    preparation
                }
                
                if !species.lookalikes.isEmpty {
                    lookALike
                }
                
                if species.caution == .doNotEat {
                    doNotEatBanner
                } else if species.hasDeadlyLookalikeAsEdible {
                    deadlyLookalikeBanner
                }
                
                if !species.recipes.isEmpty {
                    recipes
                }
                
                if species.harvestEthics != nil {
                    ethics
                }
                
                sources
                
                footer
            }
            .padding(.all, .medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(species.commonName)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: .empty) {
            Text(species.commonName)
                .font(.largeTitle.weight(.bold))
                .padding(.bottom, .xSmall)
            
            if let maoriName = species.maoriName {
                Text(maoriName)
                    .font(.headline)
                    .bold()
                    .padding(.bottom, .xxxSmall)
            }
            
            Text(species.scientificName)
                .font(.subheadline)
                .accessibilityIdentifier("speciesDetail.scientificName")
                .italic()
                .foregroundStyle(.secondary)
                .padding(.bottom, .xxSmall)
            
            HStack(spacing: .xSmall) {
                Badge(
                    image: species.caution.image,
                    title: species.caution.displayName,
                    size: .small,
                    color: species.caution.tintColor,
                    forgroundColor: .white
                )
                
                Badge(image: species.group.image, title: species.group.displayName, size: .small)
                
                Badge(image: species.origin.image, title: species.origin.displayName, size: .small)
            }
            .padding(.bottom, .xSmall)
            
            if !species.photos.isEmpty || species.moreImagesURL != nil {
                SpeciesPhotoStrip(species: species)
                    .padding(.bottom, .xSmall)
            }
            season
        }
    }
    
    private var season: some View {
        createSectionHeader(image: Image(.calendar), title: "Season", subTitle: species.seasonDescription)
    }
    
    private var description: some View {
        VStack(alignment: .leading, spacing: .xxSmall) {
            createSectionHeader(image: Image(systemName: "pencil.and.list.clipboard"), title: "Description")
            Text(species.summary.text)
                .font(.caption)
        }
    }
    
    private var habitat: some View {
        VStack(alignment: .leading, spacing: .xxxSmall) {
            HabitatView(habitats: species.habitats, layoutDirection: .leftToRight, icon: Image(.mapSearch), includeName: true)
                .padding(.bottom, .xxSmall)
            Text(species.habitat.text)
                .font(.caption)
        }
    }
    
    private var howToFindIt: some View {
        VStack(alignment: .leading, spacing: .xxxSmall) {
            createSectionHeader(image: Image(.search), title: "How To Find It")
            Text(species.identification.text)
                .font(.caption)
        }
    }
    
    private var edibleParts: some View {
        VStack(alignment: .leading, spacing: .xxxSmall) {
            createSectionHeader(image: Image(.forkKnife), title: "Edible Parts")
            Text(species.edibleParts.text)
                .font(.caption)
        }
    }
    
    private var preparation: some View {
        VStack(alignment: .leading, spacing: .xxxSmall) {
            createSectionHeader(image: Image(.pot), title: "Preparation")
            Text(species.preparation.text)
                .font(.caption)
        }
    }
    
    private var lookALike: some View {
        VStack(alignment: .leading, spacing: .empty) {
            createSectionHeader(image: Image(.outlineQuestion), title: "Look Alike")
                .padding(.bottom, .xxSmall)
            HStack(spacing: .xxSmall) {
                Image(.outlineExclamation)
                    .icon(size: .custom(size: 12), color: .primary)
                Text("Safety")
                    .font(.caption2)
                    .bold()
            }
            .padding(.bottom, .xSmall)
            
            VStack(alignment: .leading, spacing: .xxSmall) {
                ForEach(species.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: .xSmall) {
                        Text("•")
                            .font(.caption2)
                            .italic()
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        
                        Text(warning)
                            .font(.caption2)
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, .xSmall)
            
            VStack(alignment: .leading, spacing: .xxSmall) {
                ForEach(model.lookalikeCards) { card in
                    LookalikeCardView(model: card)
                }
            }
        }
    }
    
    private var recipes: some View {
        Button {
            // TODO: go to recepies page
        } label: {
            HStack(spacing: .xxSmall) {
                Image(.chefHat)
                    .icon(size: .small, color: .accent)
                Text("How can I cook it? \(model.species.recipes.count) recipes")
                Spacer()
                Image(.chevronRight)
                    .icon(size: .small, color: .accent)
            }
        }
    }
    
    private var ethics: some View {
        VStack(alignment: .leading, spacing: .xxxSmall) {
            createSectionHeader(image: Image(systemName: "hands.sparkles"), title: "Harvesting & tikanga")
            Text(model.species.harvestEthics?.text ?? "")
                .font(.caption)
        }
    }
    
    @ViewBuilder
    private var sources: some View {
        
        VStack(alignment: .leading, spacing: .xxxSmall) {
            createSectionHeader(image: Image(systemName: "book.closed"), title: "Sources")
            if species.isVerified {
                ForEach(species.sources, id: \.self) { source in
                    Text(source)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
            else {
                HStack(alignment: .top, spacing: .xxSmall) {
                    CautionLevel.careRequired.image
                        .icon(size: .small, color: .cautionCare)
                    Text("This entry has not been verified against a published field guide. Treat it as a starting point for your own identification, not an authority.")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func createSectionHeader(image: Image, title: LocalizedStringResource, subTitle: String? = nil) -> some View {
        HStack(spacing: .xxSmall) {
            image
                .icon(size: .small, color: .primary)
            VStack(alignment: .leading, spacing: .empty) {
                Text(title)
                    .font(.caption)
                    .bold()
                if let subTitle {
                    Text(subTitle)
                        .font(.caption2)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
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
    
    private func banner(title: LocalizedStringKey, message: LocalizedStringKey, tint: Color, systemImage: String) -> some View {
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
    
    private var footer: some View {
        Text(
            """
            This guide describes what to check — it cannot identify a plant for you. \
            Never eat anything you have not positively identified with an experienced \
            forager. If you suspect poisoning, call the National Poisons Centre on \
            \(PoisonsCentre.displayNumber).
            """
        )
        .font(.caption2)
        .italic()
        .foregroundStyle(.secondary)
        .padding(.bottom, .medium)
    }
    
    /// Titles are `LocalizedStringKey` so the string catalog picks them up at build time.
    private func section(
        _ title: LocalizedStringKey,
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
}
