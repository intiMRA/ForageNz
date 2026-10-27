import Foundation

/// A recipe's method laid out as a recipe: yield, notes, ingredients, numbered steps.
///
/// `Recipe.method` is one paragraph of prose, kept unstructured on purpose (see `Recipe`), so
/// the layout is read out of the prose rather than stored. Sentences that open with a source
/// line ("Written for …", "The author's …") become notes, "Serves 4" / "Makes one jar" the
/// yield, a list sentence before the first instruction the ingredients ("Filling: …" starts a
/// named group), and every other sentence a numbered step. Nothing is reworded: every word of
/// the method lands in the card, bar a joining "and", "then" or "for the" that a list or group
/// heading replaces.
///
/// The same rules lay out the recipes in `docs/catalogue.html` — `parse_recipe` in
/// `Tools/catalogue_report.py`. Change both together, or the report stops showing what the
/// app shows.
nonisolated struct RecipeCard: Equatable, Sendable {
    struct IngredientGroup: Equatable, Sendable {
        /// "Filling", "Seasoning"; `nil` for a recipe's only list.
        let name: String?
        let items: [String]
    }

    struct Step: Equatable, Sendable {
        /// "Pastry" in "Pastry: pulse the flour …".
        let label: String?
        let text: String
    }

    private(set) var yield: [String] = []
    /// Source notes before the first step: who it was written for, what the author used.
    private(set) var lede: [String] = []
    private(set) var ingredients: [IngredientGroup] = []
    /// A remark about the list that shares its sentence: "…; the author usually uses 250 ml of each."
    private(set) var ingredientNotes: [String] = []
    private(set) var steps: [Step] = []
    /// Notes after the first step: the author's cautions, unit conversions.
    private(set) var notes: [String] = []

    init(method: String) {
        for sentence in Self.sentences(in: method) {
            add(sentence)
        }
    }

    private mutating func add(_ whole: String) {
        let started = !steps.isEmpty
        if Self.note.matchesPrefix(whole) || Self.remark.matches(whole) {
            if started {
                notes.append(whole)
            }
            else {
                lede.append(whole)
            }
            return
        }

        var sentence = whole
        if let end = Self.forPeople.prefixEnd(in: sentence) {
            yield.append(String(sentence[..<end]).trimmingTrailing(": "))
            sentence = String(sentence[end...]).capitalizingFirstLetter()
        }
        if Self.yieldLine.matchesPrefix(sentence) && sentence.count < 80 {
            yield.append(sentence.trimmingTrailing("."))
            return
        }

        var label: String?
        var body = sentence
        if let groups = Self.label.wholeMatchGroups(sentence) {
            label = groups[0]
            body = groups[1]
        }
        if let end = Self.youNeed.prefixEnd(in: body) {
            body = String(body[end...])
        }

        let (listed, aside) = Self.splitAside(body)
        // After the first step only an unmistakable list still counts: "First infuse the
        // vodka …. 75 ml sake, 15 ml gin, 15 ml of the vodka …"
        let strong = Self.commaItems(listed.trimmingTrailing("."))
            .filter { Self.quantity.matchesPrefix($0) }
            .count >= 3
        if (!started || strong) && Self.isIngredientList(listed) {
            ingredients += Self.ingredientGroups(label: label, text: listed)
            if let aside {
                ingredientNotes.append(aside)
            }
        }
        else {
            steps.append(Step(label: label, text: body))
        }
    }
}

// MARK: - Reading the prose

private extension RecipeCard {
    static let note = Pattern(
        "^(Written for|From (?!day)|The author|The source|The recipe|Metric|Millilitres|"
            + "Of his lists|He |She |Adapted|Converted|Built|Made from|Made with|Recorded|The amounts|"
            + "The quantities|Keeps|It keeps|They keep|"
            + "Ready (?:after|in)|Good (?:on|with|as))"
    )
    /// A caution or aside wherever it sits in the sentence: "…; the author warns not to …".
    static let remark = Pattern("\\b(the author|he|she) (warns|notes|says)\\b")
    static let yieldLine = Pattern("^(Serves|Makes|Feeds|Fills)\\b")
    static let forPeople = Pattern("^For (?:\\d+|one|two|three|four|five|six|eight|ten)\\b[^:.;]{0,30}:\\s*")
    static let label = Pattern(
        "^(?:For the )?([A-Z]?[a-z]+(?: [a-z]+)?(?: \\([^()]*\\))?):\\s+(.*)$",
        options: .dotMatchesLineSeparators
    )
    static let youNeed = Pattern("^You(?:'ll| will)? need\\s+")
    /// Words that make a sentence an instruction or a remark rather than a list of things.
    static let verbish = Pattern(
        "\\b(is|are|was|were|until|then|so|can|should|will|keeps?|need|needs|leave|use|uses|"
            + "must|warns?|says?)\\b"
    )
    static let quantity = Pattern(
        "^(\\d|½|¼|¾|⅓|a |an |the |some |about |half |one |two |three |four |five |six |"
            + "several |plenty |enough |equal |extra |more |another |plus |optional)",
        options: .caseInsensitive
    )
    static let groupLabel = Pattern(
        "^for (?:the )?([a-z]+(?: [a-z]+)?),\\s*(.*)$",
        options: .dotMatchesLineSeparators
    )
    static let parentheses = Pattern("\\([^()]*\\)")
    /// Openers of a descriptor that belongs to the item before it: "…, peeled and cored".
    static let trailer = Pattern("^(\\w+ed|\\w+ly|stems?|with|without|peel|seeds?|skin|or|at|in|for|such)\\b")
    static let participle = Pattern("^\\w+ed\\b")
    static let preposition = Pattern("\\b(or|in|for|into|to|with|until|lengthways|from|on)\\b")
    static let conditional = Pattern("^if \\w+( \\w+)?$")
    static let thenBreak = Pattern("\\s+—\\s+then\\s+|^then\\s+")
    static let plusBreak = Pattern("\\s+—\\s+plus\\s+")

    /// Sentence openers that make it an instruction, never a list: "Blanch 12 dock leaves, …".
    static let imperatives: Set<String> = [
        "add", "bake", "beat", "blanch", "blend", "blitz", "boil", "bring", "brown", "brush",
        "butter", "chill", "chop", "clean", "combine", "cook", "cool", "cover", "cream",
        "crumble", "crush", "cut", "dilute", "dip", "dissolve", "divide", "drain", "dress",
        "drink", "drizzle", "drop", "fill", "finish", "flatten", "fold", "fry", "garnish",
        "gather", "grate", "grease", "grind", "halve", "heat", "infuse", "keep", "knead", "ladle",
        "lay", "layer", "leave", "let", "lift", "line", "make", "mash", "melt", "mix", "muddle",
        "pack", "peel", "pick", "pour", "prepare", "press", "pulse", "purée", "put",
        "refrigerate", "rest", "return", "rinse", "roast", "roll", "rub", "run", "sauté",
        "scatter", "scoop", "score", "seal", "season", "serve", "shake", "shape", "sieve",
        "simmer", "slice", "soak", "soften", "spoon", "spread", "sprinkle", "squeeze", "steam",
        "steep", "sterilise", "stir", "store", "strain", "strip", "sweat", "sweeten", "take",
        "taste", "tear", "tip", "toast", "top", "toss", "trim", "turn", "twist", "uncover", "use",
        "warm", "wash", "whip", "whisk", "wilt", "wrap", "finely", "roughly", "lightly",
        "gently", "thinly",
    ]
    /// Imperatives that are also ingredient words ("peel and all", "butter"), so they only
    /// mark an instruction at the very start of a sentence.
    static let nounsToo: Set<String> = [
        "peel", "top", "butter", "line", "season", "score", "rest", "dress", "brown", "tip",
    ]

    /// Splits after `.`, `!` or `?` where the next sentence opens with a capital, a digit, a
    /// fraction or a bracket — so "1.25 ml" and "M. campbellii" stay whole.
    static func sentences(in method: String) -> [String] {
        let openers = CharacterSet.uppercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "(½¼¾“\""))
        var result: [String] = []
        var current = ""
        let characters = Array(method.trimmingCharacters(in: .whitespacesAndNewlines))
        var index = 0
        while index < characters.count {
            let character = characters[index]
            current.append(character)
            index += 1
            guard ".!?".contains(character) else { continue }
            var next = index
            while next < characters.count, characters[next].isWhitespace {
                next += 1
            }
            if next > index, next < characters.count,
               characters[next].unicodeScalars.allSatisfy(openers.contains) {
                result.append(current)
                current = ""
                index = next
            }
        }
        result.append(current)
        return result.map { $0.trimmed }.filter { !$0.isEmpty }
    }

    /// Splits on `separator` outside parentheses.
    static func topLevelSplit(_ text: String, on separator: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var rest = Substring(text)
        while let character = rest.first {
            if depth == 0 && rest.hasPrefix(separator) {
                parts.append(current)
                current = ""
                rest = rest.dropFirst(separator.count)
                continue
            }
            if character == "(" { depth += 1 }
            if character == ")" { depth -= 1 }
            current.append(character)
            rest = rest.dropFirst()
        }
        parts.append(current)
        return parts.map { $0.trimmed }.filter { !$0.isEmpty }
    }

    /// "peeled and cored", "finely chopped", "soaked in the hot water" — but not "sliced
    /// day-old white bread", a new item that opens with a participle.
    static func isTrailer(_ part: String) -> Bool {
        guard trailer.matchesPrefix(part) else { return false }
        guard participle.matchesPrefix(part) else { return true }
        return part.split(separator: " ").count <= 3 || preposition.matches(part)
    }

    static func commaItems(_ text: String) -> [String] {
        let parts = topLevelSplit(text, on: ",").flatMap { plusBreak.split($0) }
        var items: [String] = []
        for part in parts {
            if !items.isEmpty && isTrailer(part) {
                items[items.count - 1] += ", " + part
            }
            else {
                items.append(part)
            }
        }
        // "…, 60 ml parmesan and, if you like, 300 g tofu": the aside goes with the next item.
        var index = items.count - 2
        while index >= 0 {
            if conditional.matchesPrefix(items[index]) {
                items[index...(index + 1)] = [items[index] + ", " + items[index + 1]]
                if index > 0 && items[index - 1].hasSuffix(" and") {
                    items[index - 1] = String(items[index - 1].dropLast(4))
                }
            }
            index -= 1
        }
        // "… a handful of wild garlic and a little dulse": split the last item at its final
        // "and" when what follows is a new quantity, not "salt and pepper".
        if let last = items.last, let range = last.range(of: " and ", options: .backwards) {
            let head = String(last[..<range.lowerBound])
            let tail = String(last[range.upperBound...])
            if !head.isEmpty && quantity.matchesPrefix(tail) {
                items.removeLast()
                items += [head, tail]
            }
        }
        return items
    }

    /// A list sentence as named groups of items. Two or more semicolons separate items
    /// ("2 cloves garlic, minced; olive oil; …"); a single one separates comma lists, and
    /// "for the seasoning, …" after it starts a group of its own.
    static func ingredientGroups(label: String?, text: String) -> [IngredientGroup] {
        let parts = topLevelSplit(text.trimmingTrailing("."), on: ";")
        var groups: [(name: String?, items: [String])] = [(label, [])]
        for whole in parts {
            var part = whole
            if let named = groupLabel.wholeMatchGroups(part) {
                groups.append((named[0].capitalizingFirstLetter(), []))
                part = named[1]
            }
            for piece in thenBreak.split(part) {
                let split = commaItems(piece)
                let listed = split.filter { quantity.matchesPrefix($0) }.count
                let keepsCommas = parts.count <= 2 || (split.count > 2 && listed * 2 >= split.count)
                groups[groups.count - 1].items += keepsCommas ? split : [piece]
            }
        }
        return groups.compactMap { group in
            let items = group.items.map(cleaned).filter { !$0.isEmpty }
            return items.isEmpty ? nil : IngredientGroup(name: group.name, items: items)
        }
    }

    static func cleaned(_ item: String) -> String {
        for joiner in ["and ", "plus "] where item.hasPrefix(joiner) {
            return String(item.dropFirst(joiner.count)).trimmed
        }
        return item.trimmed
    }

    static func opensWithInstruction(_ text: String) -> Bool {
        let words = text.split(separator: " ", maxSplits: 2)
            .map { $0.trimmingTrailing(",:").lowercased() }
        guard let first = words.first else { return false }
        // "Carefully twist …", "Half fill a jar …"
        if words.count > 1,
           first.hasSuffix("ly") || ["half", "first", "then"].contains(first),
           imperatives.contains(words[1]) || words[1] == "fill" {
            return true
        }
        return imperatives.contains(first)
    }

    /// "Equal parts sorrel, sugar and water; the author usually uses 250 ml of each." — a
    /// list, then a remark about it after its one semicolon.
    static func splitAside(_ text: String) -> (list: String, aside: String?) {
        let parts = topLevelSplit(text, on: ";")
        if parts.count == 2,
           verbish.matches(parts[1]),
           !verbish.matches(parentheses.removingMatches(in: parts[0])) {
            return (parts[0], parts[1].capitalizingFirstLetter())
        }
        return (text, nil)
    }

    static func isIngredientList(_ text: String) -> Bool {
        if opensWithInstruction(text) {
            return false
        }
        let semicolons = text.filter { $0 == ";" }.count
        if semicolons >= 2 {
            return true
        }
        // "In a large saucepan, bring the sugar …", "The night before, soak …"
        let commaParts = topLevelSplit(text, on: ",")
        for part in commaParts.dropFirst() {
            let verb = (part.split(separator: " ").first.map(String.init) ?? "").lowercased()
            if imperatives.contains(verb) && !nounsToo.contains(verb) && !verb.hasSuffix("ly") {
                return false
            }
        }
        if verbish.matches(parentheses.removingMatches(in: text)) {
            return false
        }
        let lists = semicolons + commaParts.count - 1
        if lists >= 2 {
            return true
        }
        // "400 g dried pasta and 5 ml salt for the water."
        return quantity.matchesPrefix(text)
            && (lists >= 1 || commaItems(text.trimmingTrailing(".")).count >= 2)
    }
}

// MARK: - Helpers

/// A compiled regular expression with the few questions the reader asks of it.
///
/// `NSRegularExpression` rather than `Regex`: the rules are shared with the Python report, and
/// ICU's `\b`, `\w` and lookahead behave as Python's `re` does on this text.
private nonisolated struct Pattern: Sendable {
    /// `nil` only if the literal does not compile — a programming error that `RecipeCardTests`
    /// catch, since a pattern that never matches leaves its recipes unstructured.
    private let regex: NSRegularExpression?

    init(_ pattern: String, options: NSRegularExpression.Options = []) {
        regex = try? NSRegularExpression(pattern: pattern, options: options)
    }

    func matches(_ text: String) -> Bool {
        regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    func matchesPrefix(_ text: String) -> Bool {
        prefixEnd(in: text) != nil
    }

    /// Where a match anchored at the start of `text` ends.
    func prefixEnd(in text: String) -> String.Index? {
        guard let match = regex?.firstMatch(
            in: text,
            options: .anchored,
            range: NSRange(text.startIndex..., in: text)
        ) else { return nil }
        return Range(match.range, in: text)?.upperBound
    }

    /// The capture groups of a match covering the whole of `text`.
    func wholeMatchGroups(_ text: String) -> [String]? {
        guard let match = regex?.firstMatch(
            in: text,
            options: .anchored,
            range: NSRange(text.startIndex..., in: text)
        ), Range(match.range, in: text)?.upperBound == text.endIndex else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }

    func split(_ text: String) -> [String] {
        var pieces: [String] = []
        var start = text.startIndex
        for match in regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? [] {
            guard let range = Range(match.range, in: text) else { continue }
            pieces.append(String(text[start..<range.lowerBound]))
            start = range.upperBound
        }
        pieces.append(String(text[start...]))
        return pieces.filter { !$0.isEmpty }
    }

    func removingMatches(in text: String) -> String {
        regex?.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ""
        ) ?? text
    }
}

private extension StringProtocol {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Drops trailing characters found in `characters`, as Python's `rstrip` does.
    func trimmingTrailing(_ characters: String) -> String {
        var result = String(self)
        while let last = result.last, characters.contains(last) {
            result.removeLast()
        }
        return result
    }

    func capitalizingFirstLetter() -> String {
        prefix(1).uppercased() + dropFirst()
    }
}
