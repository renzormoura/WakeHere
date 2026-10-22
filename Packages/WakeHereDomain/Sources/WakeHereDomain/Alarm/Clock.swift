import Foundation

/// Abstração de relógio (**DIP**: testes injetam um relógio falso).
public protocol Clock {
    var now: Date { get }
}

public struct SystemClock: Clock {
    public init() {}

    public var now: Date {
        Date()
    }
}
