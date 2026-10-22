import SwiftUI
import MapKit
import AcordeAquiDomain

/// ViewModel da tela de planejamento (MVVM).
@MainActor
final class TripPlanViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [Destination] = []
    @Published var selectedDestination: Destination?
    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
    )

    // Regra de despertar
    @Published var ruleKind: RuleKind = .time
    @Published var minutes: Double = 10
    @Published var kilometers: Double = 1

    @Published var isSearching = false
    @Published var isStarting = false
    @Published var errorMessage: String?

    private let searcher: PlaceSearching

    init(searcher: PlaceSearching) {
        self.searcher = searcher
    }

    // MARK: - Busca

    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await searcher.searchPlaces(matching: query)
        } catch {
            searchResults = []
            errorMessage = "Não foi possível buscar lugares. Verifique sua conexão."
        }
    }

    func select(_ destination: Destination) {
        selectedDestination = destination
        searchResults = []
        searchText = destination.name
        moveCamera(to: destination.coordinate, span: 0.05)
    }

    /// Pino tocado no mapa.
    func dropPin(at coordinate: Coordinate) {
        selectedDestination = Destination(
            name: "Ponto escolhido",
            subtitle: "Marcado no mapa",
            coordinate: coordinate
        )
        searchResults = []
    }

    // MARK: - Regra

    func makeRule(settings: AppSettings) -> any WakeUpRule {
        switch ruleKind {
        case .time:
            return TimeBeforeArrivalRule(
                threshold: .minutes(minutes),
                safetyMargin: .minutes(Double(settings.defaultSafetyMarginMinutes))
            )
        case .distance:
            return DistanceBeforeArrivalRule(threshold: Meters(kilometers * 1000))
        }
    }

    // MARK: - Início

    func startTrip(root: CompositionRoot) async {
        guard let destination = selectedDestination else {
            errorMessage = "Escolha um destino no mapa ou na busca."
            return
        }
        isStarting = true
        defer { isStarting = false }

        let rule = makeRule(settings: root.currentSettings)
        await root.startTrip(destination: destination, rule: rule)

        if root.session == nil {
            errorMessage = "Não foi possível iniciar a viagem. Tente novamente."
        }
    }

    private func moveCamera(to coordinate: Coordinate, span: Double) {
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate.clLocationCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                )
            )
        }
    }
}
