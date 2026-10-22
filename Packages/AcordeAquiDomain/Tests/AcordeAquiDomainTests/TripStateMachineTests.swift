import XCTest
@testable import AcordeAquiDomain

final class TripStateMachineTests: XCTestCase {
    func testHappyPathLifecycle() {
        let machine = TripStateMachine()
        XCTAssertEqual(machine.phase, .planned)

        XCTAssertTrue(machine.transition(to: .tracking))
        XCTAssertTrue(machine.transition(to: .warning))
        XCTAssertTrue(machine.transition(to: .ringing))
        XCTAssertTrue(machine.transition(to: .tracking))
        XCTAssertTrue(machine.transition(to: .warning))
        XCTAssertTrue(machine.transition(to: .ringing))
        XCTAssertTrue(machine.transition(to: .arrived))
        XCTAssertEqual(machine.phase, .arrived)
    }

    func testIllegalTransitionIsRejected() {
        let machine = TripStateMachine()
        XCTAssertFalse(machine.transition(to: .ringing))
        XCTAssertFalse(machine.transition(to: .arrived))
        XCTAssertEqual(machine.phase, .planned)
    }

    func testSameStateTransitionIsRejected() {
        let machine = TripStateMachine(initialPhase: .tracking)
        XCTAssertFalse(machine.transition(to: .tracking))
    }

    func testCancelIsAllowedFromActivePhases() {
        for phase in [TripPhase.tracking, .warning, .ringing, .snoozed] {
            let machine = TripStateMachine(initialPhase: phase)
            XCTAssertTrue(machine.transition(to: .cancelled), "deveria cancelar de \(phase)")
        }
    }

    func testTerminalStatesAreFinal() {
        for terminal in [TripPhase.arrived, .cancelled] {
            let machine = TripStateMachine(initialPhase: terminal)
            for next in TripPhase.allCases {
                XCTAssertFalse(machine.transition(to: next), "\(terminal) → \(next) deveria ser ilegal")
            }
        }
    }

    func testSnoozeRoundTrip() {
        let machine = TripStateMachine(initialPhase: .ringing)
        XCTAssertTrue(machine.transition(to: .snoozed))
        XCTAssertTrue(machine.transition(to: .ringing))
    }

    func testPhaseActivityFlags() {
        XCTAssertTrue(TripPhase.tracking.isActive)
        XCTAssertTrue(TripPhase.warning.isActive)
        XCTAssertTrue(TripPhase.ringing.isActive)
        XCTAssertTrue(TripPhase.snoozed.isActive)
        XCTAssertFalse(TripPhase.planned.isActive)
        XCTAssertTrue(TripPhase.arrived.isTerminal)
        XCTAssertTrue(TripPhase.cancelled.isTerminal)
    }
}
