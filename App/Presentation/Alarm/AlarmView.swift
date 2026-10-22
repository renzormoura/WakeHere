import SwiftUI
import AcordeAquiDomain

/// Tela de alarme em tela cheia (exibida no momento do gatilho).
struct AlarmView: View {
    @ObservedObject var session: TripSessionController
    @EnvironmentObject private var root: CompositionRoot

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.system(size: 72))
                .foregroundStyle(.yellow)
                .symbolEffect(.variableColor.iterative, options: .repeating)

            Text("ACORDE!")
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(.red)

            VStack(spacing: 6) {
                Text("Você está chegando em")
                    .foregroundStyle(.secondary)
                Text(session.trip.destination.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if let snapshot = session.snapshot {
                    Text(
                        "Faltam \(Formatting.distance(snapshot.remainingMeters.value, unit: root.currentSettings.distanceUnit))"
                    )
                    .font(.title3)
                    .foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 14) {
                Button {
                    session.stopAlarm()
                } label: {
                    Label("Parar alarme", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)

                Button {
                    session.snooze()
                } label: {
                    Label("Adiar 3 min", systemImage: "clock.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
    }
}
