import Foundation

/// What a typed query asks for: the words to look for in an entry's text, and any words that
/// name one of the guide's own facets — a group, an origin, a habitat, a month.
///
/// "fungi march" narrows to fungi in season in March; "kanuka" finds kānuka; "native fruit"
/// finds native and endemic fruit, "watercress stream" finds watercress among wetland entries.
/// The facet words are the guide's own labels (see `Vocabulary`, which a test holds to the
/// labels), plus the habitat synonyms the owner approved (docs/plans/ai-search.md, table A).
///
/// A word that names a facet can also be part of a species name — "bush" in bush lawyer. So an
/// entry whose names contain the whole query is always a result, whatever the facets say.
nonisolated struct SpeciesSearch: Equatable {
    /// The whole query, folded. Empty means the query asks for nothing and everything matches.
    let phrase: String
    /// Folded words left after the facet words and filler words are taken out. Each must
    /// appear somewhere in an entry's text.
    let terms: [String]
    let groups: Set<ForageGroup>
    let origins: Set<ForageOrigin>
    let habitats: Set<Habitat>
    let months: Set<ForageMonth>

    /// Whether any word in the query named a facet — what the screen reports back.
    var recognisesFacets: Bool {
        !groups.isEmpty || !origins.isEmpty || !habitats.isEmpty || !months.isEmpty
    }

    /// `currentMonth` is what "in season" means; it is read only if the query says it.
    init(_ query: String, currentMonth: @autoclosure () -> ForageMonth) {
        phrase = Self.fold(query)
        var words = phrase.split(separator: " ").map(String.init)
        var groups = Set<ForageGroup>()
        var origins = Set<ForageOrigin>()
        var habitats = Set<Habitat>()
        var months = Set<ForageMonth>()

        // Two-word labels first, so "in season" is not read as the filler "in" plus "season".
        var index = 0
        while index < words.count - 1 {
            let pair = words[index] + " " + words[index + 1]
            if pair == Vocabulary.inSeason {
                months.insert(currentMonth())
            } else if let habitat = Vocabulary.habitat(for: pair) {
                habitats.insert(habitat)
            } else {
                index += 1
                continue
            }
            words.removeSubrange(index...index + 1)
        }

        var terms: [String] = []
        for word in words {
            if let group = Vocabulary.groups[word] {
                groups.insert(group)
            } else if let matched = Vocabulary.origins[word] {
                origins.formUnion(matched)
            } else if let habitat = Vocabulary.habitat(for: word) {
                habitats.insert(habitat)
            } else if let month = Vocabulary.months[word] {
                months.insert(month)
            } else if !Vocabulary.filler.contains(word) {
                terms.append(word)
            }
        }

        self.terms = terms
        self.groups = groups
        self.origins = origins
        self.habitats = habitats
        self.months = months
    }

    /// A search put together from parts rather than read from typed words — what the
    /// on-device model's reading of a plain-language query becomes (`PlainWordsSearch`).
    /// `terms` are folded here, so a caller can pass words as the user typed them.
    init(
        terms: [String],
        groups: Set<ForageGroup> = [],
        origins: Set<ForageOrigin> = [],
        habitats: Set<Habitat> = [],
        months: Set<ForageMonth> = []
    ) {
        phrase = ""
        self.terms = terms.map(Self.fold).filter { !$0.isEmpty }
        self.groups = groups
        self.origins = origins
        self.habitats = habitats
        self.months = months
    }

    /// The same filters with no words to match.
    var withoutTerms: SpeciesSearch {
        SpeciesSearch(terms: [], groups: groups, origins: origins, habitats: habitats, months: months)
    }

    /// Whether the search asks for anything at all; one that does not matches everything.
    var isEmpty: Bool { phrase.isEmpty && terms.isEmpty && !recognisesFacets }

    /// The entries that answer the query, best match first; ties keep the order given.
    /// `index` holds the entries' text already folded; an entry it lacks is folded here.
    func results(from species: [ForageSpecies], index: Index = .empty) -> [ForageSpecies] {
        guard !isEmpty else { return species }
        return species.enumerated()
            .compactMap { offset, entry in score(entry, index.text(for: entry)).map { (offset, entry, $0) } }
            .sorted { $0.2 != $1.2 ? $0.2 > $1.2 : $0.0 < $1.0 }
            .map(\.1)
    }

    /// How well an entry answers the query, or `nil` if it does not. Names outrank the
    /// summary, which outranks the identification and habitat prose, all matched at the start of
    /// a word; a word found inside a name ("cress" in watercress) ranks last. Prose is never
    /// matched mid-word, so "ash" does not find every entry that says "wash".
    private func score(_ entry: ForageSpecies, _ text: FoldedText) -> Int? {
        let names = text.names
        let phraseInName = !phrase.isEmpty && Self.startsWord(names, phrase)

        guard phraseInName || matchesFacets(entry) else { return nil }

        let summary = text.summary
        let prose = text.prose
        var total = phraseInName ? 100 : 0
        for term in terms {
            if Self.startsWord(names, term) {
                total += 4
            } else if Self.startsWord(summary, term) {
                total += 3
            } else if Self.startsWord(prose, term) {
                total += 2
            } else if names.contains(term) {
                // Inside a name, at the lowest rank: "cress" still finds watercress.
                total += 1
            } else if !phraseInName {
                return nil
            }
        }
        return total
    }

    private func matchesFacets(_ entry: ForageSpecies) -> Bool {
        if !groups.isEmpty, !groups.contains(entry.group) { return false }
        if !origins.isEmpty, !origins.contains(entry.origin) { return false }
        if !habitats.isEmpty, habitats.isDisjoint(with: entry.habitats) { return false }
        if !months.isEmpty, !months.contains(where: entry.isInSeason(in:)) { return false }
        return true
    }

    // MARK: - Folding

    /// An entry's text as search reads it. Folding walks every character, so each entry is
    /// folded once, ahead of time.
    struct FoldedText: Sendable {
        let names: String
        let summary: String
        /// The identification and habitat prose, which rank below the summary.
        let prose: String

        init(_ entry: ForageSpecies) {
            names = SpeciesSearch.fold(entry.searchableNames)
            summary = SpeciesSearch.fold(entry.summary.text)
            prose = SpeciesSearch.fold(entry.identification.text + " " + entry.habitat.text)
        }
    }

    /// The catalogue's text folded ahead of time, by entry id. Built once when the catalogue
    /// loads (`SpeciesStore.searchIndex`).
    struct Index: Sendable {
        private let texts: [String: FoldedText]

        static let empty = Index(texts: [:])

        init(_ species: [ForageSpecies]) {
            texts = Dictionary(species.map { ($0.id, FoldedText($0)) }, uniquingKeysWith: { first, _ in first })
        }

        private init(texts: [String: FoldedText]) {
            self.texts = texts
        }

        func text(for entry: ForageSpecies) -> FoldedText {
            texts[entry.id] ?? FoldedText(entry)
        }
    }

    /// Lowercased, without macrons or other marks, with punctuation as spaces and runs of
    /// space collapsed — so "Tūtae-kākā" and "tutae kaka" fold to the same words.
    static func fold(_ text: String) -> String {
        let plain = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_NZ"))
        let spaced = plain.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }

    /// Whether `word` appears in `text` at the start of a word — "bush lawyer" in "bush lawyer
    /// tataramoa", but "ash" not in "wash". Both sides are folded, so spaces separate words.
    private static func startsWord(_ text: String, _ word: String) -> Bool {
        text.hasPrefix(word) || text.contains(" " + word)
    }
}

extension SpeciesSearch {
    /// The guide's own words for its facets, folded. Each one is taken from a label the app
    /// already shows (`displayName`, `shortLabel` or the raw value), plus the singular of a
    /// plural label; `SpeciesSearchTests` fails any word the labels do not carry.
    enum Vocabulary {
        static let inSeason = "in season"

        static let groups: [String: ForageGroup] = [
            "greens": .greens, "leaves": .greens, "leaf": .greens,
            "herbs": .herbs, "herb": .herbs, "flavour": .herbs,
            "fruit": .fruit, "berries": .fruit, "berry": .fruit,
            "fungi": .fungi,
            "seaweed": .seaweed,
            "nuts": .nuts, "nut": .nuts, "seeds": .nuts, "seed": .nuts
        ]

        /// "native" takes in the endemic entries too: endemic species are native ones found
        /// nowhere else, which is how `ForageOrigin.isNative` reads it.
        static let origins: [String: Set<ForageOrigin>] = [
            "endemic": [.endemic],
            "native": [.native, .endemic],
            "introduced": [.introduced],
            "weed": [.pest], "weeds": [.pest], "pest": [.pest], "pests": [.pest]
        ]

        static let habitats: [String: Habitat] = [
            "coastal": .coastal, "coast": .coastal, "shore": .coastal,
            "forest": .forest, "bush": .forest,
            "shrubland": .shrubland, "hedgerow": .shrubland,
            "grassland": .grassland, "pasture": .grassland,
            "wetland": .wetland, "riverbank": .wetland,
            "alpine": .alpine, "tussock": .alpine,
            "urban": .urban, "gardens": .urban, "garden": .urban,
            "disturbed": .disturbed, "waste ground": .disturbed, "disturbed ground": .disturbed
        ]

        /// "may" is both the name and the short name of May, hence the merge.
        /// Words that mean a habitat without being its label — the words
        /// `Tools/classify_habitats.py` reads as that habitat when it classifies the catalogue's
        /// prose. Approved by the owner 25/11/2026 (docs/plans/ai-search.md, table A); add a
        /// word here only with the same approval. "mānuka", "kānuka" and "sea" are left out:
        /// as search words they are names, or ambiguous.
        static let habitatSynonyms: [String: Habitat] = {
            let words: [Habitat: [String]] = [
                .coastal: ["coastline", "seashore", "beach", "dune", "sand dune", "estuary", "saltmarsh",
                           "tidal", "intertidal", "mangrove", "harbour", "rock pool", "seaside"],
                .forest: ["woodland", "woods", "canopy", "understorey", "plantation", "podocarp", "shelter belt"],
                .shrubland: ["scrub", "scrubland", "gorse", "broom", "hedge", "thicket", "bracken", "regenerating"],
                .grassland: ["paddock", "meadow", "lawn", "grass", "grassy", "farmland", "farm", "turf", "playing field"],
                .wetland: ["swamp", "bog", "marsh", "river", "stream", "streamside", "creek", "pond", "lake",
                           "lakeside", "ditch", "drain", "seepage", "freshwater", "riparian", "waterlogged"],
                .alpine: ["subalpine", "scree", "herbfield", "treeline", "mountain", "high country", "snowline"],
                .urban: ["suburb", "suburban", "city", "town", "berm", "street", "backyard", "allotment",
                         "cemetery", "churchyard", "park"],
                .disturbed: ["roadside", "verge", "wayside", "wasteland", "railway", "rubbish", "vacant",
                             "abandoned", "derelict", "fallow", "trackside", "car park", "pavement", "kerb"]
            ]
            return Dictionary(uniqueKeysWithValues: words.flatMap { habitat, list in list.map { ($0, habitat) } })
        }()

        /// The habitat a word or two-word phrase names — a label or an approved synonym, as
        /// typed or in the plural ("streams", "paddocks", "beaches").
        static func habitat(for words: String) -> Habitat? {
            var candidates = [words]
            if words.hasSuffix("es") { candidates.append(String(words.dropLast(2))) }
            if words.hasSuffix("s") { candidates.append(String(words.dropLast())) }
            return candidates.lazy.compactMap { habitats[$0] ?? habitatSynonyms[$0] }.first
        }

        static let months: [String: ForageMonth] = Dictionary(
            ForageMonth.allCases.flatMap { [(fold($0.displayName), $0), (fold($0.shortName), $0)] },
            uniquingKeysWith: { first, _ in first }
        )

        /// Words that carry no meaning for a search, so "fruit in March" asks for fruit and
        /// March, not for entries whose text contains "in", and "what can I pick in March" is
        /// not left asking for entries that say "pick".
        static let filler: Set<String> = [
            "a", "an", "the", "and", "or", "in", "on", "at", "by", "of", "with", "for", "to",
            "from", "near", "under", "what", "which", "where", "is", "are", "can", "i", "my",
            "me", "some", "any", "now", "pick", "find", "forage", "foraging", "grow", "growing",
            "grows", "look", "something", "things"
        ]
    }
}

extension ForageSpecies {
    /// The three names, for search to rank above the rest of the text.
    nonisolated var searchableNames: String {
        [commonName, maoriName, scientificName].compactMap(\.self).joined(separator: " ")
    }
}
