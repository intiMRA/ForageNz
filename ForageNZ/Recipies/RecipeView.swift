//
//  RecipeView.swift
//  ForageNZ
//
//  Created by Inti Albuquerque on 26/10/2026.
//

import SwiftUI
import DesignLibrary

struct RecipeView: View {
    @Environment(\.dismiss) var dismiss

    private let recipes: [(recipe: Recipe, card: RecipeCard)]

    init(recipies: [Recipe]) {
        recipes = recipies.map { ($0, RecipeCard(method: $0.method)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .large) {
                ForEach(Array(recipes.enumerated()), id: \.offset) { index, entry in
                    if index > 0 {
                        Divider()
                    }
                    RecipeSection(title: entry.recipe.title, card: entry.card)
                }
            }
            .padding(.all, .medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                }
                label: {
                    Text("Close")
                }
            }
        }
    }
}

private struct RecipeSection: View {
    let title: String
    let card: RecipeCard

    var body: some View {
        VStack(alignment: .leading, spacing: .medium) {
            header

            if card.steps.isEmpty && card.ingredients.isEmpty {
                Text("No method written yet.")
                    .font(.callout)
                    .italic()
                    .foregroundStyle(.secondary)
            }

            if !card.ingredients.isEmpty {
                ingredients
            }

            if !card.steps.isEmpty {
                method
            }

            if !card.notes.isEmpty {
                remark(image: Image(systemName: "lightbulb"), text: card.notes.joined(separator: .space))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .xxSmall) {
            HStack(alignment: .firstTextBaseline, spacing: .xxSmall) {
                Image(.chefHat)
                    .icon(size: .small, color: .primary)
                Text(title)
                    .font(.title3)
                    .bold()
            }

            if !card.yield.isEmpty {
                HStack(spacing: .xxSmall) {
                    Image(.forkKnife)
                        .icon(size: .small, color: .primary)
                    Text(card.yield.joined(separator: .dotSeparator))
                        .font(.footnote)
                        .bold()
                        .foregroundStyle(.tint)
                }
            }

            if !card.lede.isEmpty {
                remark(image: Image(systemName: "info.circle"), text: card.lede.joined(separator: .space))
            }
        }
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: .xxSmall) {
            SectionHeader(image: Image(systemName: "basket"), title: "Ingredients")

            ForEach(Array(card.ingredients.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: .xxxSmall) {
                    if let name = group.name {
                        Text(name)
                            .font(.footnote)
                            .bold()
                            .foregroundStyle(.secondary)
                            .padding(.top, .xxSmall)
                    }
                    ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: .xSmall) {
                            Text(String.bullet)
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                            Text(item)
                        }
                        .font(.callout)
                    }
                }
            }

            ForEach(card.ingredientNotes, id: \.self) { note in
                Text(note)
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var method: some View {
        VStack(alignment: .leading, spacing: .xSmall) {
            SectionHeader(image: Image(.pot), title: "Method")

            ForEach(Array(card.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: .xSmall) {
                    Text("\(index + 1)")
                        .font(.callout.monospacedDigit())
                        .bold()
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Step \(index + 1)")
                    stepText(step)
                        .font(.callout)
                }
            }
        }
    }

    private func stepText(_ step: RecipeCard.Step) -> Text {
        guard let label = step.label else {
            return Text(step.text)
        }
        return Text("\(Text("\(label):").bold()) \(step.text)")
    }

    private func remark(image: Image, text: String) -> some View {
        HStack(alignment: .top, spacing: .xxSmall) {
            image
                .icon(size: .small, color: .secondary)
            Text(text)
                .font(.footnote)
                .italic()
                .foregroundStyle(.secondary)
        }
    }
}
