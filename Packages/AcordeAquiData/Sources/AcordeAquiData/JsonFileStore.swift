import Foundation
import AcordeAquiDomain

/// Leitura/escrita JSON em arquivo (helper interno do pacote Data).
enum JsonFileStore {
    static func read<T: Decodable>(
        _ type: T.Type,
        from url: URL,
        decoder: JSONDecoder
    ) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PersistenceError.writeFailure
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw PersistenceError.corruptedData
        }
    }

    static func write<T: Encodable>(
        _ value: T,
        to url: URL,
        encoder: JSONEncoder
    ) throws {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw PersistenceError.writeFailure
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PersistenceError.writeFailure
        }
    }
}
