import Foundation
import FoundationModels
import OSLog

/// Reads a plain-language search — "white flowers by a stream", "the sorrel with purple
/// leaves" — with Apple's on-device model, and turns it into an ordinary `SpeciesSearch`.
///
/// **The model reads the user's words; it never writes the guide's.** Its only output is a
/// `SearchReading`: which of the guide's groups, origins, habitats and months the words point
/// at, and which of the words to look for. Every field is an enum case or one of the user's
/// own words — a word the query does not contain is dropped — so nothing the model makes up
/// can reach the screen. The rows that come back are catalogue entries, showing their own
/// text. A wrong reading is a search miss, never a false claim.
///
/// On-device only. No Private Cloud Compute, no network: the app is used where there is no
/// signal. Where the model is unavailable (no Apple Intelligence, model not downloaded), the
/// field guide's own word search is all there is, and the "Search in plain words" button says
/// why when tapped (`unavailableReason`). The model does not run in the simulator at all.
@MainActor
enum PlainWordsSearch {
    private static let logger = Logger(subsystem: Logging.subsystem, category: "plainWordsSearch")

    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Why the model cannot read a search on this device, in words the user can act on; `nil`
    /// when it can.
    static var unavailableReason: LocalizedStringResource? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "Plain-words search needs a device that supports Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Plain-words search needs Apple Intelligence. Turn it on in Settings."
        case .unavailable(.modelNotReady):
            return "Plain-words search is waiting for Apple Intelligence to finish downloading."
        case .unavailable:
            return "Plain-words search is not available on this device."
        }
    }

    /// Whether a query reads as a sentence rather than a name — worth the model's time.
    nonisolated static func isWorthReading(_ query: String) -> Bool {
        SpeciesSearch.fold(query).split(separator: " ").count >= 3
    }

    /// The model's reading of `query`, or `nil` if it could not read it.
    static func read(_ query: String, currentMonth: ForageMonth) async -> SpeciesSearch? {
        guard isAvailable else {
            logger.info("Plain-words search unavailable: \(String(describing: SystemLanguageModel.default.availability), privacy: .public)")
            return nil
        }
        let session = LanguageModelSession(model: .default, instructions: instructions(currentMonth: currentMonth))
        do {
            let response = try await session.respond(
                to: query,
                generating: SearchReading.self,
                options: GenerationOptions(sampling: .greedy)
            )
            let search = response.content.search(keepingWordsFrom: query)
            logger.info("Plain-words search read \(search.terms.count) words and \(search.recognisesFacets ? "some" : "no") filters")
            return search
        } catch {
            logger.error("Plain-words search failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func instructions(currentMonth: ForageMonth) -> Instructions {
        Instructions("""
        You turn a search typed into a New Zealand foraging field guide into search filters.
        Pick only the filters the search clearly asks for and leave the rest empty.
        Words: copy only the words from the search that describe the plant, fungus or seaweed \
        itself — a name, a colour, a part, a shape. Leave out general words such as plant, \
        mushroom or thing, and words you have already turned into a filter. Never add a word \
        that is not in the search.
        Habitat: a stream, river, swamp or bog is wetland; a beach, dune or estuary is coastal; \
        bush and woodland are forest; grass, a paddock or a lawn is grassland; a roadside or \
        waste ground is disturbed; a garden or park is urban.
        Months: only months the search names, or \(currentMonth.displayName) — this month — \
        for "now" or "in season".
        """)
    }
}

/// What the model may say about a query: cases of the guide's own classifications, and words.
/// Kept apart from the catalogue enums so the catalogue model, which also builds for the
/// command-line tools, does not depend on FoundationModels.
@Generable(description: "Search filters for a foraging field guide")
struct SearchReading {
    @Guide(description: "Words copied from the search that describe the species")
    var words: [String]

    @Guide(description: "Kinds of food the search asks for")
    var groups: [ReadingGroup]

    @Guide(description: "Origins the search asks for")
    var origins: [ReadingOrigin]

    @Guide(description: "Kinds of place the search asks for")
    var habitats: [ReadingHabitat]

    @Guide(description: "Months the search asks for")
    var months: [ReadingMonth]

    /// The reading as a search. Words the query does not contain are dropped, which is what
    /// keeps model-made text off the screen: the search line echoes these words back.
    func search(keepingWordsFrom query: String) -> SpeciesSearch {
        let typed = Set(SpeciesSearch.fold(query).split(separator: " ").map(String.init))
        var kept: [String] = []
        for word in words.flatMap({ SpeciesSearch.fold($0).split(separator: " ").map(String.init) })
        where typed.contains(word) && !SpeciesSearch.Vocabulary.filler.contains(word) && !kept.contains(word) {
            kept.append(word)
        }
        return SpeciesSearch(
            terms: kept,
            groups: Set(groups.map(\.group)),
            origins: Set(origins.flatMap(\.origins)),
            habitats: Set(habitats.map(\.habitat)),
            months: Set(months.map(\.month))
        )
    }
}

@Generable
enum ReadingGroup {
    case greens, herbs, fruit, fungi, seaweed, nuts

    var group: ForageGroup {
        switch self {
        case .greens: .greens
        case .herbs: .herbs
        case .fruit: .fruit
        case .fungi: .fungi
        case .seaweed: .seaweed
        case .nuts: .nuts
        }
    }
}

@Generable
enum ReadingOrigin {
    case native, endemic, introduced, weed

    /// "native" takes in endemic, as the typed search does.
    var origins: [ForageOrigin] {
        switch self {
        case .native: [.native, .endemic]
        case .endemic: [.endemic]
        case .introduced: [.introduced]
        case .weed: [.pest]
        }
    }
}

@Generable
enum ReadingHabitat {
    case coastal, forest, shrubland, grassland, wetland, alpine, urban, disturbed

    var habitat: Habitat {
        switch self {
        case .coastal: .coastal
        case .forest: .forest
        case .shrubland: .shrubland
        case .grassland: .grassland
        case .wetland: .wetland
        case .alpine: .alpine
        case .urban: .urban
        case .disturbed: .disturbed
        }
    }
}

@Generable
enum ReadingMonth {
    case january, february, march, april, may, june, july, august, september, october, november, december

    var month: ForageMonth {
        switch self {
        case .january: .january
        case .february: .february
        case .march: .march
        case .april: .april
        case .may: .may
        case .june: .june
        case .july: .july
        case .august: .august
        case .september: .september
        case .october: .october
        case .november: .november
        case .december: .december
        }
    }
}
