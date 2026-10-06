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
                
                lookALike
                
                recipes
                
                ethics
                
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
                    image: species.caution.badgeIcon,
                    title: species.caution.displayName,
                    size: .small,
                    color: species.caution.tintColor,
                    forgroundColor: species.caution.badgeForeground
                )
                
                Badge(image: .tinted(species.group.image), title: species.group.displayName, size: .small)
                
                Badge(image: .tinted(species.origin.image), title: species.origin.displayName, size: .small)
            }
            .padding(.bottom, .xSmall)

            // Debug builds only: a shipped page is never a draft. On its own line rather than
            // in the row above, which already carries three badges and has no room to wrap.
            if species.draft {
                HStack {
                    UnverifiedBadge()
                    if species.needsBookSource {
                        BookOnlyBadge()
                    }
                }
                .padding(.bottom, .xSmall)
            }
            
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
        textSection(
            image: Image(systemName: "pencil.and.list.clipboard"),
            title: "Description",
            text: species.summary.text
        )
    }
    
    /// Not a `textSection`: the classification icons sit between the header and the prose.
    /// The header is drawn here rather than inside `HabitatView` so it survives an entry with
    /// no classified habitats — `HabitatView` renders nothing at all in that case, which would
    /// otherwise leave this section's prose with no title.
    private var habitat: some View {
        VStack(alignment: .leading, spacing: .xxxSmall) {
            createSectionHeader(image: Image(.mapSearch), title: "Habitat")
            HabitatView(habitats: species.habitats, layoutDirection: .leftToRight, includeName: true)
            Text(species.habitat.text)
                .font(.caption)
        }
    }
    
    private var howToFindIt: some View {
        textSection(image: Image(.search), title: "How To Find It", text: species.identification.text)
    }

    @ViewBuilder
    private var edibleParts: some View {
        if !species.edibleParts.isBlank {
            textSection(image: Image(.forkKnife), title: "Edible Parts", text: species.edibleParts.text)
        }
    }

    @ViewBuilder
    private var preparation: some View {
        if !species.preparation.isBlank {
            textSection(image: Image(.pot), title: "Preparation", text: species.preparation.text)
        }
    }
    
    @ViewBuilder
    private var lookALike: some View {
        if !species.lookalikes.isEmpty {
            VStack(alignment: .leading, spacing: .empty) {
                createSectionHeader(image: Image(.outlineQuestion), title: "Look Alike")
                    .padding(.bottom, .xxSmall)
                // A `.psychoactive` entry gets neither banner yet: "do not eat" is the wrong
                // reason and "before you harvest this" is the wrong instruction. It needs one
                // line of its own, and that sentence is the owner's to write.
                if species.caution == .doNotEat {
                    doNotEatBanner
                        .padding(.bottom, .xxxSmall)
                }
                else if species.hasDeadlyLookalikeAsEdible {
                    deadlyLookalikeBanner
                        .padding(.bottom, .xxxSmall)
                }
                
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
                        // The styling is set once on the row: `font`, `italic` and
                        // `foregroundStyle` are inherited by both `Text`s.
                        HStack(alignment: .top, spacing: .xSmall) {
                            Text("•")
                                .accessibilityHidden(true)
                            
                            Text(warning)
                        }
                        .font(.caption2)
                        .italic()
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, .xSmall)
    
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: .xSmall) {
                        ForEach(model.lookalikeCards) { card in
                            LookalikeCardView(model: card)
                                .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in
                                    width - CommonPadding.xSmall.rawValue
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
    
    @ViewBuilder
    private var recipes: some View {
        if !species.recipes.isEmpty {
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
    }
    
    @ViewBuilder
    private var ethics: some View {
        if species.harvestEthics != nil {
            textSection(
                image: Image(systemName: "hands.sparkles"),
                title: "Harvesting & tikanga",
                text: species.harvestEthics?.text ?? ""
            )
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
    
    /// A titled section whose body is one block of catalogue prose. Five of the page's
    /// sections are exactly this and differ only in their icon, title and field.
    private func textSection(image: Image, title: LocalizedStringResource, text: String) -> some View {
        VStack(alignment: .leading, spacing: .xxxSmall) {
            createSectionHeader(image: image, title: title)
            Text(text)
                .font(.caption)
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
    
    private var doNotEatBanner: some View {
        HStack(alignment: .top, spacing: .xxxSmall) {
            CautionLevel.doNotEat.image
                .icon(size: .custom(size: 12), color: .cautionDanger)
            Text("Do not eat, this entry is here so you can recognise this species and avoid it.")
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)
        }
    }
    
    private var deadlyLookalikeBanner: some View {
        HStack(alignment: .top, spacing: .xxxSmall) {
            CautionLevel.doNotEat.image
                .icon(size: .custom(size: 12), color: .cautionDanger)
            Text("Has a deadly lookalike, read the lookalikes section below before you harvest this.")
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)
        }
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
    }
    
}
