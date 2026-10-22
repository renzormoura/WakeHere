import Foundation
import WakeHereDomain

/// **Repository** concreto: histórico de viagens em `trips.json` (Codable).
///
/// 100% local, sem servidor. Acesso serializado por fila para segurança.
public final class JsonTripRepository: TripRepository {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.wakehere.trips")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// - Parameter directory: diretório onde `trips.json` será gravado.
    public init(directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("trips.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    public func fetchAll() throws -> [Trip] {
        try queue.sync {
            let trips: [Trip]? = try JsonFileStore.read([Trip].self, from: fileURL, decoder: decoder)
            return trips ?? []
        }
    }

    public func findById(_ id: UUID) throws -> Trip? {
        try fetchAll().first { $0.id == id }
    }

    public func save(_ trip: Trip) throws {
        try queue.sync {
            var trips: [Trip] = (try? JsonFileStore.read([Trip].self, from: fileURL, decoder: decoder)) ?? []
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index] = trip
            } else {
                trips.append(trip)
            }
            try JsonFileStore.write(trips, to: fileURL, encoder: encoder)
        }
    }

    public func delete(id: UUID) throws {
        try queue.sync {
            var trips: [Trip] = (try? JsonFileStore.read([Trip].self, from: fileURL, decoder: decoder)) ?? []
            guard trips.contains(where: { $0.id == id }) else { return }
            trips.removeAll { $0.id == id }
            if trips.isEmpty {
                try? FileManager.default.removeItem(at: fileURL)
            } else {
                try JsonFileStore.write(trips, to: fileURL, encoder: encoder)
            }
        }
    }
}
