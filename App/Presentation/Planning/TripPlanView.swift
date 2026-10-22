import SwiftUI
import MapKit
import WakeHereDomain

/// Tela de planejamento: mapa + busca + regra de despertar.
struct TripPlanView: View {
    @ObservedObject var vm: TripPlanViewModel
    @EnvironmentObject private var root: CompositionRoot

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                mapSection
                formSection
            }
            .navigationTitle("Nova viagem")
            .onAppear {
                if root.locationManager.authorizationStatus == .notDetermined {
                    root.locationManager.requestWhenInUseAuthorization()
                }
            }
            .alert(
                "Atenção",
                isPresented: Binding(
                    get: { vm.errorMessage != nil },
                    set: { if !$0 { vm.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    // MARK: - Mapa

    private var mapSection: some View {
        MapReader { proxy in
            Map(position: $vm.cameraPosition) {
                UserAnnotation()

                if let destination = vm.selectedDestination {
                    Marker(
                        destination.name,
                        systemImage: "mappin.and.ellipse",
                        coordinate: destination.coordinate.clLocationCoordinate
                    )
                    .tint(.red)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .frame(minHeight: 260)
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                vm.dropPin(at: Coordinate(coordinate))
            }
        }
    }

    // MARK: - Formulário

    private var formSection: some View {
        Form {
            Section {
                TextField("Buscar lugar (ex.: Terminal Tietê)", text: $vm.searchText)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await vm.search() }
                    }

                if vm.isSearching {
                    ProgressView("Buscando…")
                }

                ForEach(vm.searchResults) { result in
                    Button {
                        vm.select(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .foregroundStyle(.primary)
                            if let subtitle = result.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let destination = vm.selectedDestination {
                    LabeledContent("Destino", value: destination.name)
                }
            } header: {
                Text("Para onde você vai?")
            } footer: {
                Text("Toque no mapa para soltar um pino no ponto exato em que você precisa descer.")
            }

            Section {
                Picker("Acordar por", selection: $vm.ruleKind) {
                    Text("Tempo").tag(RuleKind.time)
                    Text("Distância").tag(RuleKind.distance)
                }
                .pickerStyle(.segmented)

                if vm.ruleKind == .time {
                    Stepper(value: $vm.minutes, in: 1...180, step: 1) {
                        HStack {
                            Text("Avisar")
                            Spacer()
                            Text("\(Int(vm.minutes)) min antes")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Avisar a")
                            Spacer()
                            Text(Formatting.distance(vm.kilometers * 1000, unit: .metric))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $vm.kilometers, in: 0.1...20, step: 0.1)
                    }
                }
            } header: {
                Text("Regra de despertar")
            } footer: {
                Text(ruleFooter)
            }

            Section {
                Button {
                    Task { await vm.startTrip(root: root) }
                } label: {
                    HStack {
                        Spacer()
                        if vm.isStarting {
                            ProgressView()
                        } else {
                            Label("Iniciar viagem", systemImage: "play.fill")
                        }
                        Spacer()
                    }
                }
                .disabled(vm.selectedDestination == nil || vm.isStarting)
            }
        }
    }

    private var ruleFooter: String {
        switch vm.ruleKind {
        case .time:
            return "O alarme toca quando faltar \(Int(vm.minutes)) minutos para chegar. Esse horário é dinâmico: durante a viagem ele é recalculado com tráfego ao vivo (como um Maps/Waze), não é um horário fixo."
        case .distance:
            return "O alarme toca faltando \(Formatting.distance(vm.kilometers * 1000, unit: .metric)) do ponto. Esse gatilho é dinâmico: ele é recalculado com tráfego ao vivo durante a viagem."
        }
    }
}
