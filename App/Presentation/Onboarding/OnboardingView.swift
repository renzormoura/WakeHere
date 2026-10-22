import SwiftUI

/// Primeira tela: explica o app em uma passada.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Point: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private let points = [
        Point(
            symbol: "mappin.and.ellipse",
            title: "Marque onde quer acordar",
            detail: "Busque um endereço ou toque no mapa para soltar o pino no ponto em que você precisa descer."
        ),
        Point(
            symbol: "slider.horizontal.3",
            title: "Escolha quando ser avisado",
            detail: "Tocando quanto tempo antes (ex.: 10 min) ou quanta distância antes (ex.: 1 km) do ponto."
        ),
        Point(
            symbol: "bell.and.waves.left.and.right",
            title: "Durma tranquilo",
            detail: "O AcordeAqui acompanha a viagem em segundo plano e dispara o alarme na hora certa — mesmo com o iPhone bloqueado."
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            Text("AcordeAqui")
                .font(.largeTitle.bold())
                .padding(.top, 32)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(points) { point in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: point.symbol)
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(point.title).font(.headline)
                            Text(point.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Text("Durante a viagem o app usa sua localização em segundo plano para calcular o tempo e a distância até o destino.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Começar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
