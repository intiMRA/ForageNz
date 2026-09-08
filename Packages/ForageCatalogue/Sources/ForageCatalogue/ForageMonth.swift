import Foundation

/// A calendar month, used to express when a species is worth looking for.
///
/// Seasons follow the southern-hemisphere calendar: summer is December–February.
public nonisolated enum ForageMonth: Int, Codable, Sendable, CaseIterable, Comparable {
    case january = 1
    case february
    case march
    case april
    case may
    case june
    case july
    case august
    case september
    case october
    case november
    case december

    public var displayName: String {
        switch self {
        case .january: "January"
        case .february: "February"
        case .march: "March"
        case .april: "April"
        case .may: "May"
        case .june: "June"
        case .july: "July"
        case .august: "August"
        case .september: "September"
        case .october: "October"
        case .november: "November"
        case .december: "December"
        }
    }

    public var shortName: String {
        switch self {
        case .january: "Jan"
        case .february: "Feb"
        case .march: "Mar"
        case .april: "Apr"
        case .may: "May"
        case .june: "Jun"
        case .july: "Jul"
        case .august: "Aug"
        case .september: "Sep"
        case .october: "Oct"
        case .november: "Nov"
        case .december: "Dec"
        }
    }

    public static let count = allCases.count

    public static func < (lhs: ForageMonth, rhs: ForageMonth) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Treats the calendar as circular, so December is immediately before January.
    public func isImmediatelyAfter(_ other: ForageMonth) -> Bool {
        (other.rawValue % Self.count) + 1 == rawValue
    }

    /// Months forward from `other` to `self`, wrapping at the end of the year.
    public func monthsAfter(_ other: ForageMonth) -> Int {
        (rawValue - other.rawValue + Self.count) % Self.count
    }

    /// Falls back to `.january` only if the calendar yields a month outside 1...12,
    /// which `Calendar` does not do for a valid `Date`.
    public static func containing(_ date: Date, calendar: Calendar = .current) -> ForageMonth {
        ForageMonth(rawValue: calendar.component(.month, from: date)) ?? .january
    }
}
