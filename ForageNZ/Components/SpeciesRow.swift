import DesignLibrary
import SwiftUI

struct SpeciesRow: View {
    let model: ListingRowModel
    
    var body: some View {
        HStack(alignment: .top, spacing: .small) {
            leftView
            rightView
        }
        .padding(.all, .xSmall)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.rowCardBackground)
                .shadow(color: .shadow, radius: 2)
        }
    }
    
    var leftView: some View {
        VStack(alignment: .leading) {
            BundledPhoto(fileName: model.photoFileName ?? "")
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Spacer()
            groupView
        }
    }
    
    var rightView: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                infoView
                Spacer()
                Badge(
                    image: model.caution.image,
                    title: model.caution.shortLabel,
                    size: .small,color: model.caution.tintColor,
                    forgroundColor: .white
                )
            }
            
            Spacer()
            
            HStack(alignment: .top) {
                seasonView
                Spacer()
                HabitatView(habitats: model.habitats, layoutDirection: .rightToLeft)
            }
        }
    }
    
    var groupView: some View {
        VStack(alignment: .leading, spacing: .xxxSmall) {
            Text("Group:")
                .bold()
                .font(.footnote)
            model.group.image
                .icon(size: .standard, color: .primary)
        }
        
    }
    
    var seasonView: some View {
        VStack(alignment: .leading, spacing: .xxxSmall) {
            Text("Season:")
                .bold()
                .font(.footnote)
            Text(model.seasonDescription)
                .font(model.seasonDescription.contains(",") ? .caption2 : .footnote)
                .foregroundStyle(.secondary)
                .italic()
        }
    }
    
    var infoView: some View {
        VStack(alignment: .leading, spacing: .empty) {
            Text(model.commonName)
                .font(.headline)
                .accessibilityIdentifier("speciesRow.\(model.speciesID.rawValue)")
                .foregroundStyle(.primary)
            
            Text(model.scientificName)
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)
                .padding(.bottom, .xSmall)
            
            Text(model.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .padding(.bottom, .medium)
        }
    }
}
