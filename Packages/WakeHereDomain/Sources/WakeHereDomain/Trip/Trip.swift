import Foundation

/// Entidade central: uma viagem configurada pelo usuário.
///
/// Classe (referência) porque é vivida ao longo do tempo: o `TripMonitor`
/// atualiza `phase`, `route` e `lastSnapshot` conforme a viagem acontece.
public final class Trip: Identifiable, Codable {
    public let id: UUID
    public var destination: Destination
    public var route: Route?
    public var phase: TripPhase
    /// Regra de despertar (**Strategy**, tipo opaco).
    public var rule: any WakeUpRule
    public var createdAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    /// Última medição processada (para retomar a UI).
    public var lastSnapshot: TripSnapshot?

    public init(
        id: UUID = UUID(),
        destination: Destination,
        rule: any WakeUpRule,
        route: Route? = nil,
        phase: TripPhase = .planned,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        lastSnapshot: TripSnapshot? = nil
    ) {
        self.id = id
        self.destination = destination
        self.route = route
        self.phase = phase
        self.rule = rule
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.lastSnapshot = lastSnapshot
    }

    // MARK: - Codable polimórfico

    private enum CodingKeys: String, CodingKey {
        case id, destination, route, phase, encodedRule
        case createdAt, startedAt, finishedAt, lastSnapshot
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        destination = try container.decode(Destination.self, forKey: .destination)
        route = try container.decodeIfPresent(Route.self, forKey: .route)
        phase = try container.decode(TripPhase.self, forKey: .phase)
        let encodedRule = try container.decode(EncodedWakeUpRule.self, forKey: .encodedRule)
        rule = try WakeUpRuleCodec.decode(encodedRule)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt)
        lastSnapshot = try container.decodeIfPresent(TripSnapshot.self, forKey: .lastSnapshot)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(destination, forKey: .destination)
        try container.encodeIfPresent(route, forKey: .route)
        try container.encode(phase, forKey: .phase)
        try container.encode(WakeUpRuleCodec.encode(rule), forKey: .encodedRule)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(finishedAt, forKey: .finishedAt)
        try container.encodeIfPresent(lastSnapshot, forKey: .lastSnapshot)
    }
}
