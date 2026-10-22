import Foundation

public enum PersistenceError: Error, Equatable {
    case corruptedData
    case writeFailure
}

/// Porta (**Repository pattern**) para o histórico de viagens.
public protocol TripRepository: AnyObject {
    func fetchAll() throws -> [Trip]
    func findById(_ id: UUID) throws -> Trip?
    func save(_ trip: Trip) throws
    func delete(id: UUID) throws
}

/// Sistema de unidades preferido pelo usuário.
public enum DistanceUnit: String, Codable, CaseIterable, Sendable {
    case metric
    case imperial
}

/// Configurações do app (persistidas).
public struct AppSettings: Codable, Hashable, Sendable {
    public var distanceUnit: DistanceUnit
    public var defaultSafetyMarginMinutes: Int
    /// Volume do alarme 0...1.
    public var alarmVolume: Double
    public var soundEnabled: Bool
    public var hapticsEnabled: Bool

    public init(
        distanceUnit: DistanceUnit = .metric,
        defaultSafetyMarginMinutes: Int = 0,
        alarmVolume: Double = 1.0,
        soundEnabled: Bool = true,
        hapticsEnabled: Bool = true
    ) {
        self.distanceUnit = distanceUnit
        self.defaultSafetyMarginMinutes = defaultSafetyMarginMinutes
        self.alarmVolume = min(max(alarmVolume, 0), 1)
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
    }

    public static let `default` = AppSettings()
}

/// Porta (**Repository pattern**) para as configurações.
public protocol SettingsRepository: AnyObject {
    func load() throws -> AppSettings
    func save(_ settings: AppSettings) throws
}
