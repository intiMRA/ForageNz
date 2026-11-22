import Foundation
import Testing

import ForageCatalogue

@Suite("Associations")
struct AssociationTests {
    private func makeSpecies(id: String, associations: [Association] = []) -> ForageSpecies {
        ForageSpecies(
            id: id, commonName: id, scientificName: "Testus \(id)",
            group: .fungi, origin: .introduced, caution: .straightforward,
            summary: "A summary.", habitat: "Somewhere.", identification: "Distinctive.",
            edibleParts: "Cap.", preparation: "Fry.",
            associations: associations
        )
    }

    @Test("Each kind's reverse is its inverse, and root partners are symmetric")
    func reverseKinds() {
        #expect(AssociationKind.mycorrhizalPartner.reverse == .mycorrhizalPartner)
        #expect(AssociationKind.parasiteOf.reverse == .hostOf)
        #expect(AssociationKind.growsOnDeadWoodOf.reverse == .deadWoodHostOf)
        for kind in AssociationKind.allCases {
            #expect(kind.reverse.reverse == kind)
        }
    }

    @Test("A partnership recorded on both pages is not one-way")
    func twoWayLinksPass() {
        let catalogue = [
            makeSpecies(id: "slippery-jack", associations: [
                Association(kind: .mycorrhizalPartner, entry: .montereyPine, note: "Only under pine.")
            ]),
            makeSpecies(id: "monterey-pine", associations: [
                Association(kind: .mycorrhizalPartner, entry: .slipperyJack, note: "Fruits under it.")
            ])
        ]
        #expect(AssociationLink.oneWay(in: catalogue).isEmpty)
    }

    @Test("A link with no reverse is reported, from the side that carries it")
    func missingReverseIsReported() {
        let catalogue = [
            makeSpecies(id: "slippery-jack", associations: [
                Association(kind: .mycorrhizalPartner, entry: .montereyPine, note: "Only under pine.")
            ]),
            makeSpecies(id: "monterey-pine")
        ]
        #expect(AssociationLink.oneWay(in: catalogue) == [
            AssociationLink(from: .slipperyJack, kind: .mycorrhizalPartner, to: .montereyPine)
        ])
    }

    @Test("A reverse of the wrong kind does not count — a parasite's host is not a parasite of it")
    func wrongReverseKindIsReported() {
        let catalogue = [
            makeSpecies(id: "slippery-jack", associations: [
                Association(kind: .parasiteOf, entry: .montereyPine, note: "Lives off it.")
            ]),
            makeSpecies(id: "monterey-pine", associations: [
                Association(kind: .parasiteOf, entry: .slipperyJack, note: "Lives off it.")
            ])
        ]
        #expect(AssociationLink.oneWay(in: catalogue).count == 2)

        let fixed = [
            catalogue[0],
            makeSpecies(id: "monterey-pine", associations: [
                Association(kind: .hostOf, entry: .slipperyJack, note: "Its host.")
            ])
        ]
        #expect(AssociationLink.oneWay(in: fixed).isEmpty)
    }

    @Test("An entry written before associations existed decodes with none")
    func absentKeyDecodesEmpty() throws {
        let species = makeSpecies(id: "death-cap", associations: [
            Association(kind: .mycorrhizalPartner, entry: .englishOak, note: "Under oak.")
        ])
        let encoded = try JSONEncoder().encode(species)
        var object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "associations")
        let decoded = try JSONDecoder().decode(ForageSpecies.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.associations.isEmpty)
        #expect(try JSONDecoder().decode(ForageSpecies.self, from: encoded) == species)
    }

    @Test("A link naming a species the catalogue lacks fails to decode")
    func unknownEntryFailsToDecode() {
        let json = Data(#"{"kind":"mycorrhizalPartner","entry":"no-such-tree","note":"Under it."}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Association.self, from: json)
        }
    }
}
