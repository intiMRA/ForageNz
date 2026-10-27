import Foundation
import Testing

@testable import ForageNZ

@Suite("Recipe card")
struct RecipeCardTests {
    @Test("A list sentence before the first instruction is the ingredients")
    func listThenSteps() {
        let card = RecipeCard(
            method: "Four large flowering heads, an onion, a parsnip, a handful of wild garlic and a little dulse. "
                + "Sweat the onion in oil, add the chopped alexanders and the rest, cover with stock and simmer about 10 minutes. "
                + "Blend smooth and reheat to serve."
        )

        #expect(card.ingredients == [
            .init(
                name: nil,
                items: ["Four large flowering heads", "an onion", "a parsnip", "a handful of wild garlic", "a little dulse"]
            ),
        ])
        #expect(card.steps.map(\.text) == [
            "Sweat the onion in oil, add the chopped alexanders and the rest, cover with stock and simmer about 10 minutes.",
            "Blend smooth and reheat to serve.",
        ])
    }

    @Test("Source lines, yield and the author's later asides are kept apart from the steps")
    func notesAndYield() {
        let card = RecipeCard(
            method: "Written for wild blackberries. Serves 10. Heat the oven to 190 °C. "
                + "The author notes the patches may be sprayed."
        )

        #expect(card.lede == ["Written for wild blackberries."])
        #expect(card.yield == ["Serves 10"])
        #expect(card.steps.map(\.text) == ["Heat the oven to 190 °C."])
        #expect(card.notes == ["The author notes the patches may be sprayed."])
    }

    @Test("Storage and serving remarks are notes, and 'Fills' gives the yield")
    func storageAndServingNotes() {
        let card = RecipeCard(
            method: "Made with narrow-leaved plantain. Fills 2 jam jars. 1 kg berries; 500 g sugar; 1 lemon. "
                + "Boil everything until set. Keeps a year unopened. Good on toast."
        )

        #expect(card.lede == ["Made with narrow-leaved plantain."])
        #expect(card.yield == ["Fills 2 jam jars"])
        #expect(card.ingredients.flatMap(\.items) == ["1 kg berries", "500 g sugar", "1 lemon"])
        #expect(card.steps.map(\.text) == ["Boil everything until set."])
        #expect(card.notes == ["Keeps a year unopened.", "Good on toast."])
    }

    @Test("A labelled list starts a named group; a labelled instruction stays a step")
    func labelledGroups() {
        let card = RecipeCard(
            method: "Dough: 200 g softened butter, 200 g caster sugar and 4 eggs. "
                + "Filling: 4 medium cooking apples, peeled and cored, 200 g blackberries and 80 g caster sugar. "
                + "Sauce: whisk the cream until thick."
        )

        #expect(card.ingredients == [
            .init(name: "Dough", items: ["200 g softened butter", "200 g caster sugar", "4 eggs"]),
            .init(name: "Filling", items: ["4 medium cooking apples, peeled and cored", "200 g blackberries", "80 g caster sugar"]),
        ])
        #expect(card.steps == [.init(label: "Sauce", text: "whisk the cream until thick.")])
    }

    @Test("Semicolons separate items, and 'for the seasoning' opens a group of its own")
    func semicolonGroups() {
        let card = RecipeCard(
            method: "For two: 200 g of shoots, 1 chicken thigh and 15 ml oil; for the seasoning, 15 ml sake and 30 ml mirin. "
                + "Fry the chicken."
        )

        #expect(card.yield == ["For two"])
        #expect(card.ingredients == [
            .init(name: nil, items: ["200 g of shoots", "1 chicken thigh", "15 ml oil"]),
            .init(name: "Seasoning", items: ["15 ml sake", "30 ml mirin"]),
        ])
    }

    @Test("An instruction that lists quantities is a step, not an ingredient list")
    func instructionIsNotAList() {
        let card = RecipeCard(
            method: "Blanch 12 large dock leaves in boiling water, one or two at a time, for 30 seconds."
        )

        #expect(card.ingredients.isEmpty)
        #expect(card.steps.count == 1)
    }

    @Test("Decimals and abbreviated genus names do not end a sentence")
    func sentenceSplitting() {
        let card = RecipeCard(method: "Add 1.25 ml salt. Try M. campbellii flowers.")

        #expect(card.steps.map(\.text) == ["Add 1.25 ml salt.", "Try M. campbellii flowers."])
    }

    /// The layout must never drop part of a method: the card is the only way the app shows
    /// it. A joining "and", "then", "for the" or "you need" that a list or heading replaces is
    /// the only thing allowed to go.
    @Test("Every shipped recipe keeps every word of its method")
    func noWordIsLost() async throws {
        let joiners: Set<String> = ["and", "plus", "then", "for", "the", "you", "need"]
        func words(_ text: String) -> [String: Int] {
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "½¼¾")).inverted)
                .filter { !$0.isEmpty && !joiners.contains($0) }
                .reduce(into: [:]) { $0[$1, default: 0] += 1 }
        }

        let catalogue = try await BundledSpeciesRepository().loadSpecies()
        let recipes = catalogue.flatMap(\.recipes)
        #expect(!recipes.isEmpty)
        for recipe in recipes {
            let card = RecipeCard(method: recipe.method)
            var pieces: [String] = card.yield + card.lede + card.ingredientNotes + card.notes
            for group in card.ingredients {
                pieces += [group.name ?? ""] + group.items
            }
            for step in card.steps {
                pieces += [step.label ?? "", step.text]
            }
            let shown = pieces.joined(separator: " ")
            #expect(words(shown) == words(recipe.method), "\(recipe.title)")
        }
    }
}
