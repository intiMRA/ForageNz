import SwiftUI

/// The navigation state of one stack.
///
/// There is one of these per tab, injected into that tab's subtree, so the three stacks stay
/// independent. Screens do not push views — they tell the router where to go, which keeps the
/// route in one inspectable place instead of spread across `NavigationLink`s.
///
/// `path` is not `private(set)`: `NavigationStack` writes back to its binding when the user
/// taps Back or swipes, so a read-only path would break the gesture. Pushes still go through
/// `push` — that is the convention, not something the type can enforce here.
/// Not `@MainActor`: the environment default has to be constructible from the nonisolated
/// context `@Entry` generates. Every caller is a view body, so it is main-actor in practice.
@Observable
final class Router {
    var path: [Destination] = []

    func push(_ destination: Destination) {
        path.append(destination)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}

extension EnvironmentValues {
    /// Defaults to a router nothing is looking at, so a screen that is used outside a
    /// `NavigationStack` still compiles and simply goes nowhere. `RootView` injects a real one
    /// per tab; the UI tests are what catch it if that wiring is ever dropped.
    @Entry var router = Router()
}
