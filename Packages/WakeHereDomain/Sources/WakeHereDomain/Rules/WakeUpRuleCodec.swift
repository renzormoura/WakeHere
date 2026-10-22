import Foundation

public enum WakeUpRuleCodecError: Error, Equatable {
    case unknownDiscriminator(String)
}

/// Serialização polimórfica das regras (Strategy + Factory).
///
/// `Trip` guarda `any WakeUpRule`; este codec embute o discriminador + o JSON
/// da regra concreta, permitindo persistir regras sem perder o tipo.
public struct EncodedWakeUpRule: Codable, Hashable, Sendable {
    public let discriminator: String
    public let payload: Data

    public init(discriminator: String, payload: Data) {
        self.discriminator = discriminator
        self.payload = payload
    }
}

public enum WakeUpRuleCodec {
    public static func encode(_ rule: any WakeUpRule) throws -> EncodedWakeUpRule {
        let payload = try JSONEncoder().encode(rule)
        return EncodedWakeUpRule(
            discriminator: type(of: rule).discriminator,
            payload: payload
        )
    }

    public static func decode(_ encoded: EncodedWakeUpRule) throws -> any WakeUpRule {
        switch encoded.discriminator {
        case TimeBeforeArrivalRule.discriminator:
            return try JSONDecoder().decode(TimeBeforeArrivalRule.self, from: encoded.payload)
        case DistanceBeforeArrivalRule.discriminator:
            return try JSONDecoder().decode(DistanceBeforeArrivalRule.self, from: encoded.payload)
        default:
            throw WakeUpRuleCodecError.unknownDiscriminator(encoded.discriminator)
        }
    }
}
