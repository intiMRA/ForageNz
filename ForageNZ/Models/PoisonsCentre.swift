import Foundation

/// The National Poisons Centre contact details.
nonisolated enum PoisonsCentre {
    static let displayNumber = "0800 764 766"

    static let callURL = URL(string: "tel:\(dialDigits)")

    private static let dialDigits = "0800764766"
}
