import Foundation
import Testing

import ForageCatalogue

@Suite("ForageSpecies")
struct ForageSpeciesTests {
    private func makeSpecies(
        id: String = "test",
        caution: CautionLevel = .straightforward,
        months: [ForageMonth] = [],
        lookalikes: [Lookalike] = []
    ) -> ForageSpecies {
        ForageSpecies(
            id: id,
            commonName: "Test plant",
            scientificName: "Testus planta",
            category: .greens,
            origin: .introduced,
            caution: caution,
            months: months,
            summary: "A plant for testing.",
            habitat: "Test ground.",
            identification: "Looks like a test.",
            edibleParts: "Leaves.",
            preparation: "Boil.",
            lookalikes: lookalikes
        )
    }

    @Test("An empty month list means year-round")
    func yearRound() {
        let species = makeSpecies(months: [])
        #expect(species.isYearRound)
        #expect(species.seasonDescription == "Year-round")
        for month in ForageMonth.allCases {
            #expect(species.isInSeason(in: month))
        }
    }

    @Test("A contiguous run renders as a range")
    func contiguousSeason() {
        let species = makeSpecies(months: [.february, .march, .april])
        #expect(species.seasonDescription == "Feb – Apr")
    }

    @Test("Scattered months are listed individually, in reading order")
    func scatteredSeason() {
        let species = makeSpecies(months: [.november, .december, .february])
        #expect(species.seasonDescription == "Nov, Dec, Feb")
    }

    @Test("A season that wraps the new year renders as a range, not a numeric sort")
    func wrappingSeason() {
        // Southern-hemisphere summer. A plain numeric sort would give "Jan, Feb, Nov, Dec".
        let summer = makeSpecies(months: [.november, .december, .january, .february])
        #expect(summer.seasonDescription == "Nov – Feb")

        let plum = makeSpecies(months: [.december, .january, .february])
        #expect(plum.seasonDescription == "Dec – Feb")
    }

    @Test("Two separate harvests stay listed apart rather than collapsing")
    func splitSeason() {
        // Elder: flowers in Nov–Dec, berries in Feb–Mar.
        let elder = makeSpecies(months: [.november, .december, .february, .march])
        #expect(elder.seasonDescription == "Nov, Dec, Feb, Mar")
    }

    @Test("All twelve months is year-round, not a Jan–Dec range")
    func allMonthsIsYearRound() {
        #expect(makeSpecies(months: ForageMonth.allCases).seasonDescription == "Year-round")
    }

    @Test("A single month renders as its full name")
    func singleMonth() {
        #expect(makeSpecies(months: [.may]).seasonDescription == "May")
    }

    @Test("Seasonal species are only in season in their listed months")
    func seasonMembership() {
        let species = makeSpecies(months: [.march, .april])
        #expect(species.isInSeason(in: .march))
        #expect(species.isInSeason(in: .april))
        #expect(!species.isInSeason(in: .may))
        #expect(!species.isInSeason(in: .january))
    }

    @Test("The highest lookalike risk wins")
    func highestRisk() {
        let species = makeSpecies(lookalikes: [
            Lookalike(name: "Bland thing", risk: .unpalatable, howToTell: "Tastes bad.", entry: .catsear),
            Lookalike(name: "Lethal thing", risk: .deadly, howToTell: "Has a volva.", entry: .deathCap),
            Lookalike(name: "Nasty thing", risk: .toxic, howToTell: "Milky sap.", entry: .pettySpurge)
        ])
        #expect(species.highestLookalikeRisk == .deadly)
    }

    @Test("No lookalikes means no risk")
    func noLookalikes() {
        #expect(makeSpecies().highestLookalikeRisk == nil)
    }

    @Test("Search text covers every name field")
    func searchableText() {
        let species = ForageSpecies(
            id: "kawakawa",
            commonName: "Kawakawa",
            maoriName: "Kawakawa",
            scientificName: "Piper excelsum",
            category: .herbs,
            origin: .native,
            caution: .careRequired,
            summary: "Native pepper tree.",
            habitat: "Coastal forest.",
            identification: "Heart-shaped leaves.",
            edibleParts: "Leaves.",
            preparation: "Tea."
        )
        #expect(species.searchableText.contains("piper excelsum"))
        #expect(species.searchableText.contains("kawakawa"))
        #expect(species.searchableText.contains("native pepper tree"))
    }
}

@Suite("ForageMonth")
struct ForageMonthTests {
    @Test("A date resolves to its calendar month")
    func monthContainingDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 15

        let date = try #require(calendar.date(from: components))

        #expect(ForageMonth.containing(date, calendar: calendar) == .april)
    }
}
