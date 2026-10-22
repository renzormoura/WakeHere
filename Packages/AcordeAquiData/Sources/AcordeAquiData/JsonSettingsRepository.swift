import Foundation
import AcordeAquiDomain

/// **Repository** concreto: configurações em `settings.json`.
///
/// Arquivo ausente ou corrompido → cai nos padrões (nunca quebra o app).
public final class JsonSettingsRepository: SettingsRepository {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.acordeaqui.settings")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("settings.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    public func load() throws -> AppSettings {
        try queue.sync {
            if let settings = try? JsonFileStore.read(
                AppSettings.self,
                from: fileURL,
                decoder: decoder
            ) {
                return settings
            }
            return .default
        }
    }

    public func save(_ settings: AppSettings) throws {
        try queue.sync {
            try JsonFileStore.write(settings, to: fileURL, encoder: encoder)
        }
    }
}
