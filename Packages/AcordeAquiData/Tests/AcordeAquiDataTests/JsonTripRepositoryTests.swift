import XCTest
import AcordeAquiDomain
@testable import AcordeAquiData

final class JsonTripRepositoryTests: XCTestCase {
    private var directory: URL!
    private var repository: JsonTripRepository!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("acordeaqui-trips-\(UUID().uuidString)")
        repository = try JsonTripRepository(directory: directory)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func makeTrip(
        id: UUID = UUID(),
        name: String = "Terminal Centro",
        phase: TripPhase = .planned,
        rule: any WakeUpRule = TimeBeforeArrivalRule(threshold: .minutes(10))
    ) -> Trip {
        Trip(
            id: id,
            destination: Destination(
                name: name,
                coordinate: Coordinate(latitude: -23.56, longitude: -46.64)
            ),
            rule: rule,
            route: nil,
            phase: phase,
            createdAt: Date(timeIntervalSinceReferenceDate: 500)
        )
    }

    // MARK: - Testes

    func testFetchAllOnEmptyDirectoryReturnsEmpty() throws {
        XCTAssertEqual(try repository.fetchAll().count, 0)
    }

    func testSaveAndFetchRoundTrip() throws {
        let trip = makeTrip(phase: .tracking)
        try repository.save(trip)

        let all = try repository.fetchAll()
        XCTAssertEqual(all.count, 1)

        let loaded = try XCTUnwrap(all.first)
        XCTAssertEqual(loaded.id, trip.id)
        XCTAssertEqual(loaded.destination.name, "Terminal Centro")
        XCTAssertEqual(loaded.phase, .tracking)
        XCTAssertEqual(loaded.createdAt, trip.createdAt)

        let rule = try XCTUnwrap(loaded.rule as? TimeBeforeArrivalRule)
        XCTAssertEqual(rule.threshold, .minutes(10))
    }

    func testRoundTripWithDistanceRule() throws {
        let trip = makeTrip(rule: DistanceBeforeArrivalRule(threshold: Meters(750)))
        try repository.save(trip)

        let loaded = try XCTUnwrap(try repository.findById(trip.id))
        let rule = try XCTUnwrap(loaded.rule as? DistanceBeforeArrivalRule)
        XCTAssertEqual(rule.threshold, Meters(750))
    }

    func testSaveUpdatesTripWithSameId() throws {
        let id = UUID()
        try repository.save(makeTrip(id: id, phase: .planned))
        try repository.save(makeTrip(id: id, phase: .arrived))

        let all = try repository.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.phase, .arrived)
    }

    func testDeleteRemovesOnlyThatTrip() throws {
        let keep = makeTrip(name: "Manter")
        let remove = makeTrip(name: "Remover")
        try repository.save(keep)
        try repository.save(remove)

        try repository.delete(id: remove.id)

        let all = try repository.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, keep.id)
        XCTAssertNil(try repository.findById(remove.id))
    }

    func testDeletingLastTripRemovesFileAndStaysEmpty() throws {
        let trip = makeTrip()
        try repository.save(trip)
        try repository.delete(id: trip.id)

        XCTAssertEqual(try repository.fetchAll().count, 0)
        let file = directory.appendingPathComponent("trips.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testDeleteUnknownIdIsANoOp() throws {
        try repository.save(makeTrip())
        try repository.delete(id: UUID())
        XCTAssertEqual(try repository.fetchAll().count, 1)
    }

    func testCorruptedFileThrowsCorruptedData() throws {
        let file = directory.appendingPathComponent("trips.json")
        try Data("{not json".utf8).write(to: file)

        XCTAssertThrowsError(try repository.fetchAll()) { error in
            XCTAssertEqual(error as? PersistenceError, .corruptedData)
        }
    }

    func testSaveRecoversFromCorruptedFile() throws {
        let file = directory.appendingPathComponent("trips.json")
        try Data("{not json".utf8).write(to: file)

        let trip = makeTrip()
        try repository.save(trip)

        let all = try repository.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, trip.id)
    }
}
