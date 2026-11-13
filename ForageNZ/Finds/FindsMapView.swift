import DesignLibrary
import MapKit
import SwiftUI

/// The user's finds on a map. "+" puts a cross in the middle of the map; the user moves the map
/// until the cross is where they found something, then picks the species.
struct FindsMapView: View {
    @Environment(FindsStore.self) private var finds
    @Environment(\.speciesModels) private var models

    @State private var position = MapCameraPosition.region(.newZealand)
    @State private var hasFittedFinds = false
    @State private var centre = Coordinate(CLLocationCoordinate2D.newZealandCentre)
    @State private var selectedFindID: FindSnapshot.ID?
    @State private var isPlacing = false
    @State private var showsSpeciesPicker = false
    /// The fallback for when the map tiles cannot load: the app works without a signal, and
    /// the tiles come from Apple's servers.
    @State private var showsList = false

    var body: some View {
        let pins = finds.finds.map(models.createFindPinModel)
        Group {
            if showsList {
                FindsListView(pins: pins) { id in
                    Task { await finds.deleteFind(id) }
                }
            } else {
                map(pins)
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showsSpeciesPicker) {
            SpeciesPickerView { species in
                Task { await save(species) }
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { finds.errorMessage != nil },
                set: { if !$0 { finds.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(finds.errorMessage ?? "")
        }
        .onChange(of: finds.loadState, initial: true) {
            guard !hasFittedFinds, finds.loadState == .loaded, !finds.finds.isEmpty else { return }
            hasFittedFinds = true
            position = .automatic
        }
    }

    private func map(_ pins: [FindPinModel]) -> some View {
        Map(position: $position, selection: $selectedFindID) {
            ForEach(pins) { pin in
                Annotation(pin.commonName ?? String(localized: "No longer in the guide"), coordinate: CLLocationCoordinate2D(pin.coordinate)) {
                    FindPinView(group: pin.group, isSelected: pin.id == selectedFindID)
                }
                .tag(pin.id)
            }
        }
        .onMapCameraChange(frequency: .continuous) { context in
            centre = Coordinate(context.region.center)
        }
        .overlay {
            if isPlacing {
                Image(systemName: "plus")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomPanel(pins)
        }
    }

    @ViewBuilder
    private func bottomPanel(_ pins: [FindPinModel]) -> some View {
        if isPlacing {
            placementPanel
        } else if let selectedFindID, let pin = pins.first(where: { $0.id == selectedFindID }) {
            FindCard(pin: pin) {
                self.selectedFindID = nil
                Task { await finds.deleteFind(pin.id) }
            }
        } else if pins.isEmpty, finds.loadState == .loaded {
            Text("Tap + to save where you found a species.")
                .font(.subheadline)
                .padding(.all, .medium)
                .background(.regularMaterial, in: Layout.cardShape)
                .padding(.all, .medium)
        }
    }

    private var placementPanel: some View {
        VStack(spacing: .small) {
            Text("Move the map until the cross is where you found it.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            HStack {
                Button("Cancel", role: .cancel) {
                    isPlacing = false
                }
                Spacer()
                Button {
                    Task { await moveToCurrentLocation() }
                } label: {
                    Label("My location", systemImage: "location")
                }
                .disabled(finds.isLocating)
                Spacer()
                Button("Choose species") {
                    showsSpeciesPicker = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("chooseFindSpecies")
            }
        }
        .padding(.all, .medium)
        .background(.regularMaterial, in: Layout.cardShape)
        .padding(.all, .medium)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            SyncSettingsButton()
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showsList.toggle()
            } label: {
                Label(showsList ? "Show map" : "Show as list", systemImage: showsList ? "map" : "list.bullet")
            }
            .accessibilityIdentifier("toggleFindsList")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showsList = false
                selectedFindID = nil
                isPlacing = true
            } label: {
                Label("Add a find", systemImage: "plus")
            }
            .disabled(isPlacing)
            .accessibilityIdentifier("addFind")
        }
    }

    private func moveToCurrentLocation() async {
        guard let coordinate = await finds.currentLocation() else { return }
        position = .region(MKCoordinateRegion(around: coordinate))
    }

    private func save(_ species: SpeciesID) async {
        guard let find = await finds.saveFind(of: species, at: centre) else { return }
        isPlacing = false
        selectedFindID = find.id
    }
}

private nonisolated enum FindsMapDefaults {
    static let newZealandLatitude = -41.0
    static let newZealandLongitude = 173.5
    /// Degrees: enough for both main islands on a phone screen.
    static let newZealandSpan = 14.0
    /// Degrees: a few hundred metres, close enough to place a find by eye.
    static let placementSpan = 0.01
}

private extension CLLocationCoordinate2D {
    static var newZealandCentre: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: FindsMapDefaults.newZealandLatitude,
            longitude: FindsMapDefaults.newZealandLongitude
        )
    }
}

private extension MKCoordinateRegion {
    static var newZealand: MKCoordinateRegion {
        MKCoordinateRegion(
            center: .newZealandCentre,
            span: MKCoordinateSpan(
                latitudeDelta: FindsMapDefaults.newZealandSpan,
                longitudeDelta: FindsMapDefaults.newZealandSpan
            )
        )
    }

    init(around coordinate: Coordinate) {
        self.init(
            center: CLLocationCoordinate2D(coordinate),
            span: MKCoordinateSpan(
                latitudeDelta: FindsMapDefaults.placementSpan,
                longitudeDelta: FindsMapDefaults.placementSpan
            )
        )
    }
}

extension CLLocationCoordinate2D {
    init(_ coordinate: Coordinate) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

extension Coordinate {
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
