//
//  DebugDrawer.swift
//  ForageNZ
//

/// A drawer of development switches, and the two ways to open it.
///
/// Everything but the one entry point below is `#if DEBUG`: none of it — the flags, the
/// sheet, the gesture that opens it — exists in a build anybody installs. That matters more
/// here than in most apps, because the one flag it carries unhides entries the guide
/// deliberately keeps off the phone.
///
/// Strings are `Text(verbatim:)` throughout, so developer wording never reaches the String
/// Catalog and never asks anyone to translate it.

import SwiftUI

extension View {
    /// Opens the debug drawer on ⌘D or a two-finger double tap, and keeps `store` in step with
    /// whatever the drawer's flags say. Nothing at all in a release build.
    func debugDrawer(store: SpeciesStore) -> some View {
        #if DEBUG
        modifier(DebugDrawerModifier(store: store))
        #else
        self
        #endif
    }
}

#if DEBUG

import UIKit

/// Development switches, remembered across launches so a debugging session survives a rebuild.
@MainActor
@Observable
final class DebugSettings {
    /// Lists the unfinished catalogue entries alongside the finished ones, each badged
    /// "Unverified". See `SpeciesStore.includesUnverified`, which this drives.
    var showsUnverifiedEntries: Bool {
        didSet { defaults.set(showsUnverifiedEntries, forKey: Self.unverifiedKey) }
    }

    private let defaults: UserDefaults
    private static let unverifiedKey = "debug.showsUnverifiedEntries"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `didSet` does not fire from an initialiser, so reading the stored value here cannot
        // write it straight back.
        showsUnverifiedEntries = defaults.bool(forKey: Self.unverifiedKey)
    }
}

// MARK: - The drawer

struct DebugDrawer: View {
    @Bindable var settings: DebugSettings
    /// How many entries the catalogue is currently hiding, for the footer to report.
    let unverifiedCount: Int
    let needsBookCount: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $settings.showsUnverifiedEntries) {
                        Text(verbatim: "Show unverified entries")
                    }
                } header: {
                    Text(verbatim: "Catalogue")
                } footer: {
                    Text(
                        verbatim: """
                            \(unverifiedCount) entries are unfinished drafts, and the app \
                            hides them. Turn this on to browse and open them — each is badged \
                            Unverified, in its row and on its page.

                            \(needsBookCount) of them are badged Book only: the web has been \
                            searched and has nothing, so the rest has to come off a printed page.
                            """
                    )
                }
            }
            .navigationTitle(Text(verbatim: "Debug"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text(verbatim: "Done") }
                }
            }
        }
    }
}

// MARK: - Opening it

private struct DebugDrawerModifier: ViewModifier {
    let store: SpeciesStore

    @State private var settings = DebugSettings()
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .background {
                // A real, focusable button, because `.keyboardShortcut` needs one — invisible,
                // and behind the content so it cannot take a tap.
                Button { isPresented.toggle() } label: { Text(verbatim: "Debug drawer") }
                    .keyboardShortcut("d", modifiers: .command)
                    .opacity(0)
                    .accessibilityHidden(true)

                // The gesture, for a device with no keyboard attached.
                TwoFingerDoubleTap { isPresented.toggle() }
            }
            .sheet(isPresented: $isPresented) {
                DebugDrawer(
                    settings: settings,
                    unverifiedCount: store.unverifiedCount,
                    needsBookCount: store.needsBookCount
                )
            }
            // `initial: true` so a flag left on from the last launch is applied at startup,
            // not only when someone toggles it.
            .onChange(of: settings.showsUnverifiedEntries, initial: true) { _, showsUnverified in
                store.includesUnverified = showsUnverified
            }
    }
}

/// A two-finger double tap anywhere in the app.
///
/// The recogniser is attached to the *window* rather than to this view, so it fires over a
/// scroll view, a sheet or a tab bar instead of only over the small patch of background this
/// view occupies. It takes nothing away from the UI underneath: it recognises alongside every
/// other gesture and does not cancel touches, so a tap or a scroll behaves exactly as before.
///
/// Two taps rather than one, because a single two-finger tap is close enough to a clumsy
/// one-finger tap to fire by accident while scrolling a list.
private struct TwoFingerDoubleTap: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> UIView {
        WindowGestureView(coordinator: context.coordinator)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func fire() {
            action()
        }

        func gestureRecognizer(
            _: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    private final class WindowGestureView: UIView {
        private let recogniser: UITapGestureRecognizer

        init(coordinator: Coordinator) {
            recogniser = UITapGestureRecognizer(
                target: coordinator,
                action: #selector(Coordinator.fire)
            )
            recogniser.numberOfTouchesRequired = 2
            recogniser.numberOfTapsRequired = 2
            recogniser.cancelsTouchesInView = false
            recogniser.delegate = coordinator
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("TwoFingerDoubleTap is never loaded from a nib")
        }

        /// Follows the view between windows, and takes the recogniser with it — including off,
        /// when the view is removed and `window` is nil.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            recogniser.view?.removeGestureRecognizer(recogniser)
            window?.addGestureRecognizer(recogniser)
        }
    }
}

#endif
