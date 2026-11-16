import DesignLibrary
import SwiftUI

/// Every SF Symbol the app can show, searchable and by category. Picking one sets `selection`
/// and goes back.
struct ListSymbolPicker: View {
    @Binding var selection: String?

    @Environment(\.dismiss) private var dismiss

    @State private var store = ListSymbolPickerStore()

    var body: some View {
        content
            .navigationTitle(store.category?.title ?? "Icon")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $store.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search icons"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    categoryMenu
                }
            }
            .task {
                await store.loadIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView()
        case .failed(let message):
            ContentUnavailableView {
                Label("Icons unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
        case .loaded where store.symbols.isEmpty:
            ContentUnavailableView.search(text: store.query)
        case .loaded:
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: Layout.listSymbolCellSize), spacing: CommonPadding.xSmall.rawValue)],
                spacing: CommonPadding.xSmall.rawValue
            ) {
                ForEach(store.symbols, id: \.self) { name in
                    cell(name)
                }
            }
            .padding(.all, .medium)
        }
    }

    private func cell(_ name: String) -> some View {
        let isSelected = selection == name
        return Button {
            selection = name
            dismiss()
        } label: {
            Image(systemName: name)
                .font(.title2)
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .frame(width: Layout.listSymbolCellSize, height: Layout.listSymbolCellSize)
                .background {
                    if isSelected {
                        Layout.rowCardShape.fill(.tint.opacity(Layout.bannerBackgroundOpacity))
                    }
                }
                .contentShape(Layout.rowCardShape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("listSymbol.\(name)")
    }

    private var categoryMenu: some View {
        Menu {
            Picker("Category", selection: $store.categoryKey) {
                Text("All icons")
                    .tag(ListSymbolCatalogue.Category.ID?.none)
                ForEach(store.catalogue?.categories ?? []) { category in
                    categoryLabel(category)
                        .tag(Optional(category.id))
                }
            }
        } label: {
            Label("Category", systemImage: "square.grid.2x2")
        }
        .accessibilityIdentifier("listSymbolCategory")
    }

    @ViewBuilder
    private func categoryLabel(_ category: ListSymbolCatalogue.Category) -> some View {
        if let symbol = category.symbol {
            Label(category.title, systemImage: symbol)
        } else {
            Text(category.title)
        }
    }
}
