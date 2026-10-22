import Foundation

// MARK: - Value objects de domínio (unidades tipadas)

/// Distância em metros. Tipar unidades evita erros silenciosos (km vs m).
public struct Meters: Codable, Hashable, Comparable, Sendable {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public static let zero = Meters(0)

    public var kilometers: Double { value / 1000 }

    public static func < (lhs: Meters, rhs: Meters) -> Bool {
        lhs.value < rhs.value
    }

    public static func + (lhs: Meters, rhs: Meters) -> Meters {
        Meters(lhs.value + rhs.value)
    }

    public static func - (lhs: Meters, rhs: Meters) -> Meters {
        Meters(lhs.value - rhs.value)
    }

    public static func * (lhs: Meters, rhs: Double) -> Meters {
        Meters(lhs.value * rhs)
    }

    public static func / (lhs: Meters, rhs: Double) -> Meters {
        Meters(lhs.value / rhs)
    }
}

/// Duração em segundos.
public struct Seconds: Codable, Hashable, Comparable, Sendable {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public static let zero = Seconds(0)

    public var minutes: Double { value / 60 }
    public var hours: Double { value / 3600 }

    /// Converte minutos inteiros em segundos (convenção de configuração do usuário).
    public static func minutes(_ minutes: Double) -> Seconds {
        Seconds(minutes * 60)
    }

    public static func hours(_ hours: Double) -> Seconds {
        Seconds(hours * 3600)
    }

    public static func < (lhs: Seconds, rhs: Seconds) -> Bool {
        lhs.value < rhs.value
    }

    public static func + (lhs: Seconds, rhs: Seconds) -> Seconds {
        Seconds(lhs.value + rhs.value)
    }

    public static func - (lhs: Seconds, rhs: Seconds) -> Seconds {
        Seconds(lhs.value - rhs.value)
    }

    public static func * (lhs: Seconds, rhs: Double) -> Seconds {
        Seconds(lhs.value * rhs)
    }
}

/// Velocidade em m/s (unidade canônica do sistema).
public struct MetersPerSecond: Codable, Hashable, Comparable, Sendable {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public static let zero = MetersPerSecond(0)

    public var kilometersPerHour: Double { value * 3.6 }

    public static func < (lhs: MetersPerSecond, rhs: MetersPerSecond) -> Bool {
        lhs.value < rhs.value
    }

    public static func + (lhs: MetersPerSecond, rhs: MetersPerSecond) -> MetersPerSecond {
        MetersPerSecond(lhs.value + rhs.value)
    }

    public static func * (lhs: MetersPerSecond, rhs: Double) -> MetersPerSecond {
        MetersPerSecond(lhs.value * rhs)
    }
}
