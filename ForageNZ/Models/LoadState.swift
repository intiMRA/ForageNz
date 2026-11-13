/// Where a store's one-off load has got to. A failed load may be retried.
nonisolated enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(message: String)

    /// Whether a load should start: nothing has been tried yet, or the last try failed.
    var canStart: Bool {
        switch self {
        case .idle, .failed: true
        case .loading, .loaded: false
        }
    }
}
