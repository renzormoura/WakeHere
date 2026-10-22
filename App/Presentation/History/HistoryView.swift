import SwiftUI
import AcordeAquiDomain

/// Histórico de viagens (lido do `TripRepository`).
struct HistoryView: View {
    @EnvironmentObject private var root: CompositionRoot
    @State private var trips: [Trip] = []

    var body: some View {
        NavigationStack {
            List {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "Nenhuma viagem ainda",
                        systemImage: "moon.zzz.fill",
                        description: Text(
                            "Configure seu primeiro despertador de viagem na aba Nova viagem."
                        )
                    )
                } else {
                    ForEach(trips) { trip in
                        row(for: trip)
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("Histórico")
            .toolbar {
                if !trips.isEmpty {
                    EditButton()
                }
            }
            .onAppear(perform: load)
        }
    }

    private func row(for trip: Trip) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.destination.name)
                    .font(.headline)
                Text(trip.rule.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formatting.dateTime(trip.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(
                Formatting.phaseLabel(trip.phase),
                systemImage: Formatting.phaseSymbol(trip.phase)
            )
            .font(.caption2)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(trip.phase == .arrived ? Color.green : Color.secondary)
        }
        .padding(.vertical, 2)
    }

    private func load() {
        let all = (try? root.tripRepository.fetchAll()) ?? []
        trips = all.sorted { $0.createdAt > $1.createdAt }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets where index < trips.count {
            try? root.tripRepository.delete(id: trips[index].id)
        }
        load()
    }
}
