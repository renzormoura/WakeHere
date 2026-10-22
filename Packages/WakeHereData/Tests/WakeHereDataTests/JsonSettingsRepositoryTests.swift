import XCTest
import WakeHereDomain
@testable import WakeHereData

final class JsonSettingsRepositoryTests: XCTestCase {
    private var directory: URL!
    private var repository: JsonSettingsRepository!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("wakehere-settings-\(UUID().uuidString)")
        repository = try JsonSettingsRepository(directory: directory)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    func testLoadWithoutFileReturnsDefaults() throws {
        let settings = try repository.load()
        XCTAssertEqual(settings, .default)
        XCTAssertEqual(settings.distanceUnit, .metric)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertEqual(settings.alarmVolume, 1.0, accuracy: 0.001)
    }

    func testSaveAndLoadRoundTrip() throws {
        var settings = AppSettings.default
        settings.distanceUnit = .imperial
        settings.defaultSafetyMarginMinutes = 5
        settings.alarmVolume = 0.4
        settings.soundEnabled = false
        settings.hapticsEnabled = false

        try repository.save(settings)
        let loaded = try repository.load()

        XCTAssertEqual(loaded, settings)
    }

    func testCorruptedFileFallsBackToDefaults() throws {
        try Data("garbage".utf8).write(
            to: directory.appendingPathComponent("settings.json")
        )
        let settings = try repository.load()
        XCTAssertEqual(settings, .default)
    }

    func testVolumeIsClampedOnInit() {
        XCTAssertEqual(AppSettings(alarmVolume: 2.5).alarmVolume, 1.0, accuracy: 0.001)
        XCTAssertEqual(AppSettings(alarmVolume: -1).alarmVolume, 0.0, accuracy: 0.001)
    }
}
