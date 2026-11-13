import Foundation

/// Everything that can go wrong with the user's own data: their lists and their finds.
nonisolated enum UserDataError: Error, Sendable {
    /// The store could not be opened (a corrupt file, a full disk). The feature is off for the
    /// session; the catalogue is unaffected.
    case storeUnavailable(underlying: any Error)
    case fetchFailed(underlying: any Error)
    case saveFailed(underlying: any Error)
    case listNotFound
    case findNotFound
    case emptyListName
    case duplicateListName

    var userMessage: String {
        switch self {
        case .storeUnavailable:
            "Your lists and finds can’t be opened on this device right now. The field guide still works."
        case .fetchFailed:
            "Your lists and finds couldn’t be read. Try again."
        case .saveFailed:
            "That change couldn’t be saved. Try again."
        case .listNotFound:
            "That list no longer exists."
        case .findNotFound:
            "That find no longer exists."
        case .emptyListName:
            "A list needs a name."
        case .duplicateListName:
            "You already have a list with that name."
        }
    }
}
