import SwiftUI
import MapKit
import WakeHereDomain

/// Acompanhamento da viagem ativa: mapa, contadores e controles.
struct TripTrackingView: View {
    @ObservedObject var session: TripSessionController
    @EnvironmentObject private var root: CompositionRoot
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    phaseBanner
                    map
                    liveETACard
                    countdownCard
                    trafficRefreshBadge
                    cancelButton
                }
                .padding()
            }
            .navigationTitle("Acompanhando")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Encerrar") {
                        session.cancelTrip()
                        root.session = nil
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .fullScreenCover(isPresented: $session.isAlarmVisible) {
            AlarmView(session: session)
        }
        .onChange(of: session.phase) { _, newPhase in
            if newPhase == .arrived || newPhase == .cancelled {
                root.session = nil
            }
        }
    }

    // MARK: - Banner de fase

    private var phaseBanner: some View {
        Label(
            Formatting.phaseLabel(session.phase),
            systemImage: Formatting.phaseSymbol(session.phase)
        )
        .font(.headline)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(bannerColor.opacity(0.2), in: Capsule())
        .foregroundStyle(bannerColor)
    }

    private var bannerColor: Color {
        switch session.phase {
        case .warning: return .orange
        case .ringing: return .red
        case .snoozed: return .blue
        case .arrived: return .green
        default: return .accentColor
        }
    }

    // MARK: - Mapa

    private var map: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            Marker(
                session.trip.destination.name,
                systemImage: "mappin.and.ellipse",
                coordinate: session.trip.destination.coordinate.clLocationCoordinate
            )
            .tint(.red)

            if let route = session.trip.route {
                MapPolyline(
                    coordinates: route.polyline.map { $0.clLocationCoordinate }
                )
                .stroke(.blue, lineWidth: 5)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Card de ETA dinâmico (estilo Maps/Waze)

    /// Mostra o ETA e a chegada estimada calculados em tempo real. O valor é
    /// derivado do snapshot e interpolado segundo a segundo entre updates de GPS,
    /// exatamente como o cálculo do alarme: não há tempo de chegada pré-fixado.
    private var liveETACard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 12) {
                if let snapshot = session.snapshot {
                    let elapsed = context.date.timeIntervalSince(snapshot.timestamp)
                    let remainingSeconds = max(
                        0,
                        snapshot.estimatedRemainingSeconds.value - elapsed
                    )
                    let arrival = context.date.addingTimeInterval(remainingSeconds)

                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Formatting.duration(remainingSeconds))
                                .font(.title.bold().monospacedDigit())
                                .minimumScaleFactor(0.6)
                            Text("Falta para chegar")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer()

                        VStack(spacing: 2) {
                            Text(Formatting.clockTime(arrival))
                                .font(.title.bold().monospacedDigit())
                                .minimumScaleFactor(0.6)
                            Text("Chegada estimada")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    ProgressView("Aguardando sinal de GPS…")
                        .padding(.vertical, 12)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Card de contagem regressiva

    private var countdownCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 16) {
                if let snapshot = session.snapshot {
                    // Interpola o ETA segundo a segundo entre updates de GPS.
                    let elapsed = context.date.timeIntervalSince(snapshot.timestamp)
                    let remainingSeconds = max(
                        0,
                        snapshot.estimatedRemainingSeconds.value - elapsed
                    )

                    HStack(spacing: 0) {
                        statCell(
                            symbol: "hourglass",
                            value: Formatting.duration(remainingSeconds),
                            label: "Faltam"
                        )
                        Divider().frame(height: 52).padding(.horizontal, 4)
                        statCell(
                            symbol: "point.topleft.down.to.point.bottomright.curvepath",
                            value: Formatting.distance(
                                snapshot.remainingMeters.value,
                                unit: root.currentSettings.distanceUnit
                            ),
                            label: "Distância"
                        )
                        Divider().frame(height: 52).padding(.horizontal, 4)
                        statCell(
                            symbol: "clock",
                            value: Formatting.clockTime(
                                context.date.addingTimeInterval(remainingSeconds)
                            ),
                            label: "Chegada"
                        )
                    }

                    if !snapshot.isOnRoute {
                        Label(
                            "Fora da rota — recalculando…",
                            systemImage: "location.slash.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }

                    // Dinamicidade do ETA (tráfego ao vivo vs. GPS only).
                    if snapshot.isDynamicETA {
                        Label(
                            "ETA dinâmico com tráfego ao vivo",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .font(.caption2)
                        .foregroundStyle(.green)
                    } else {
                        Label(
                            "ETA por velocidade GPS (sem tráfego ao vivo)",
                            systemImage: "antenna.radiowaves.left.and.right"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView("Aguardando sinais de GPS…")
                        .padding(.vertical, 24)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func statCell(symbol: String, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Badge de atualização dinâmica

    /// Indica que o alarme é dinâmico: horário recalculado com tráfego ao vivo
    /// a cada 3 min e a cada update de GPS, nunca um horário fixo.
    private var trafficRefreshBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption2)
            Text("Alarme dinâmico: horário recalculado com tráfego ao vivo")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary, in: Capsule())
    }

    // MARK: - Botão cancelar

    private var cancelButton: some View {
        Button(role: .destructive) {
            session.cancelTrip()
            root.session = nil
        } label: {
            Label("Cancelar viagem", systemImage: "xmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}
