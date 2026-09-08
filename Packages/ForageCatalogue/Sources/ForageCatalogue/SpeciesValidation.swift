import Foundation

/// Something wrong with an entry.
///
/// `blocking` issues are the rules `CatalogueTests` enforces, so an entry carrying one will
/// fail the build. They live here rather than only in the tests so the editor can show them
/// while you type instead of at build time.
public nonisolated struct ValidationIssue: Sendable, Hashable, Identifiable {
    public enum Severity: String, Sendable, Hashable {
        /// Fails the build.
        case blocking
        /// Worth fixing, but shippable.
        case advisory
    }

    public let field: String
    public let message: String
    public let severity: Severity

    public var id: String { "\(field)|\(message)" }

    public init(field: String, message: String, severity: Severity) {
        self.field = field
        self.message = message
        self.severity = severity
    }
}

public extension ForageSpecies {
    /// Every rule an entry must satisfy, in the order the editor shows them.
    var validationIssues: [ValidationIssue] {
        var issues: [ValidationIssue] = []

        func blocking(_ field: String, _ message: String) {
            issues.append(ValidationIssue(field: field, message: message, severity: .blocking))
        }
        func advisory(_ field: String, _ message: String) {
            issues.append(ValidationIssue(field: field, message: message, severity: .advisory))
        }

        if id.trimmed.isEmpty {
            blocking("id", "Needs an identifier.")
        } else if id.contains(where: { !($0.isLowercase && $0.isLetter) && !$0.isNumber && $0 != "-" }) {
            blocking("id", "Use lowercase letters, digits and hyphens only.")
        }

        if commonName.trimmed.isEmpty { blocking("commonName", "Needs a common name.") }
        if scientificName.trimmed.isEmpty { blocking("scientificName", "Needs a scientific name.") }
        if summary.trimmed.isEmpty { blocking("summary", "Needs a one-line summary — it's the list subtitle.") }
        if habitat.trimmed.isEmpty { blocking("habitat", "Needs habitat notes.") }
        if identification.trimmed.isEmpty { blocking("identification", "Needs identification notes.") }

        for (index, lookalike) in lookalikes.enumerated() {
            let field = "lookalikes[\(index)]"
            if lookalike.name.trimmed.isEmpty { blocking(field, "Lookalike needs a name.") }
            if lookalike.howToTell.trimmed.isEmpty {
                blocking(field, "Needs a specific, field-checkable way to tell them apart.")
            }
        }

        if highestLookalikeRisk == .deadly && caution == .straightforward {
            blocking("caution", "Has a deadly lookalike, so it can't be marked straightforward.")
        }

        switch caution {
        case .doNotEat:
            if !edibleParts.localizedCaseInsensitiveContains("none") {
                blocking("edibleParts", "A do-not-eat entry must claim no edible parts.")
            }
            if warnings.isEmpty {
                blocking("warnings", "A do-not-eat entry must say what the danger is.")
            }
        case .careRequired:
            if warnings.isEmpty && lookalikes.isEmpty {
                blocking("warnings", "Needs care, so it must say why — a warning or a lookalike.")
            }
            if edibleParts.trimmed.isEmpty { advisory("edibleParts", "No edible parts recorded.") }
            if preparation.trimmed.isEmpty { advisory("preparation", "No preparation recorded.") }
        case .straightforward:
            if edibleParts.trimmed.isEmpty { advisory("edibleParts", "No edible parts recorded.") }
            if preparation.trimmed.isEmpty { advisory("preparation", "No preparation recorded.") }
        }

        if origin == .native && (harvestEthics?.trimmed.isEmpty ?? true) {
            blocking("harvestEthics", "Native species need harvesting and tikanga guidance.")
        }

        for (index, recipe) in recipes.enumerated() where recipe.title.trimmed.isEmpty {
            blocking("recipes[\(index)]", "Recipe needs a title.")
        }

        for (index, photo) in photos.enumerated() {
            let field = "photos[\(index)]"
            if photo.caption.trimmed.isEmpty {
                blocking(field, "Needs a caption saying which feature it shows.")
            }
            if photo.credit.trimmed.isEmpty {
                blocking(field, "Needs attribution — the licence requires it and the app shows it.")
            }
        }

        let wantedPhotos = CataloguePhotos.recommendedCount(
            hasDeadlyLookalike: highestLookalikeRisk == .deadly
        )
        if caution != .doNotEat && photos.count < wantedPhotos {
            advisory(
                "photos",
                photos.isEmpty
                    ? "No photos. It can't be identified from text alone, and there is no signal in the bush to look any up."
                    : "Only \(photos.count) of \(wantedPhotos) photos."
                        + (highestLookalikeRisk == .deadly
                            ? " It has a deadly lookalike, so it needs more than usual."
                            : "")
            )
        }

        if sources.isEmpty {
            advisory("sources", "Not yet checked against a field guide.")
        } else if sources.contains(where: { $0.trimmed.isEmpty }) {
            blocking("sources", "Remove the blank source, or fill it in.")
        }

        return issues
    }

    var blockingIssues: [ValidationIssue] {
        validationIssues.filter { $0.severity == .blocking }
    }

    /// `true` when nothing about this entry would fail the build.
    var isPublishable: Bool { blockingIssues.isEmpty }

    /// A slug usable as an entry id, derived from a common name.
    ///
    /// Macrons are folded rather than dropped, so "Pūhā" becomes "puha" and not "p-h" —
    /// te reo names are common here and stripping the vowels mangles them.
    static func makeIdentifier(from name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US"))
        let mapped = folded.lowercased().map { character -> Character in
            if character.isLetter && character.isASCII { return character }
            if character.isNumber { return character }
            return "-"
        }
        return String(mapped)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
