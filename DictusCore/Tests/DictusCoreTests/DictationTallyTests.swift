// DictusCore/Tests/DictusCoreTests/DictationTallyTests.swift
// The per-day dictation counter (#726), and the recap snapshot that reads it.
//
// Each test gets its own `UserDefaults` suite, never the App Group, for the reason
// `ProTrialTests` gives (#560). The calendar is pinned to UTC so a day boundary is
// where the test says it is, whatever the Mac's time zone.
import XCTest
@testable import DictusCore

final class DictationTallyTests: XCTestCase {

    /// 2026-09-21 14:13:20 UTC.
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    private let day: TimeInterval = 86_400
    private var suiteNames: [String] = []

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "UTC")!  // A fixed, always-known identifier.
        return calendar
    }

    private func makeDefaults() -> UserDefaults {
        let name = "dictus.tests.dictationTally.\(UUID().uuidString)"
        suiteNames.append(name)
        // swiftlint:disable:next force_unwrapping
        return UserDefaults(suiteName: name)!  // A fresh, non-App-Group suite name is always valid.
    }

    override func tearDown() {
        suiteNames.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) }
        suiteNames = []
        super.tearDown()
    }

    private func record(_ words: Int, _ seconds: Int, at date: Date, in defaults: UserDefaults) {
        DictationTally.record(words: words, audioSeconds: seconds, in: defaults, now: date, calendar: utc)
    }

    // MARK: - Counting

    func testDictationsOnTheSameDayAddUp() {
        let defaults = makeDefaults()
        record(10, 4, at: t0, in: defaults)
        record(25, 9, at: t0.addingTimeInterval(3_600), in: defaults)

        XCTAssertEqual(DictationTally.totals(from: t0, through: t0, in: defaults, calendar: utc),
                       .init(words: 35, audioSeconds: 13))
        let stored = defaults.dictionary(forKey: SharedKeys.dictationTally) as? [String: [String: Int]]
        XCTAssertEqual(stored, ["2026-09-21": ["words": 35, "audioSeconds": 13]], "integers per day, no text")
    }

    func testDaysAreKeptApartAndSummedOverARange() {
        let defaults = makeDefaults()
        record(10, 5, at: t0, in: defaults)
        record(20, 8, at: t0.addingTimeInterval(day), in: defaults)
        record(40, 15, at: t0.addingTimeInterval(3 * day), in: defaults)

        XCTAssertEqual(DictationTally.totals(from: t0, through: t0.addingTimeInterval(day), in: defaults, calendar: utc),
                       .init(words: 30, audioSeconds: 13))
        XCTAssertEqual(DictationTally.totals(from: t0.addingTimeInterval(2 * day), through: t0.addingTimeInterval(2 * day),
                                             in: defaults, calendar: utc),
                       .zero, "a day with no dictation")
        XCTAssertEqual(DictationTally.totals(from: t0, through: t0.addingTimeInterval(30 * day), in: defaults, calendar: utc),
                       .init(words: 70, audioSeconds: 28))
    }

    func testAnEmptyTranscriptCountsNothing() {
        let defaults = makeDefaults()
        record(0, 12, at: t0, in: defaults)
        XCTAssertNil(defaults.object(forKey: SharedKeys.dictationTally))
    }

    func testWordsFollowTheSystemsBoundaries() {
        XCTAssertEqual(DictationTally.wordCount(of: ""), 0)
        XCTAssertEqual(DictationTally.wordCount(of: "Bonjour, comment allez-vous ?"), 4)
        XCTAssertEqual(DictationTally.wordCount(of: "  Hello   world.\nSee you  "), 4)
        XCTAssertGreaterThan(DictationTally.wordCount(of: "我今天很忙"), 1, "Mandarin writes no spaces")
    }

    // MARK: - The recap's window

    /// Writes the trial mirror the keyboard and the snapshot read, as `ProTrialStore` does.
    private func mirrorTrial(startingAt start: Date, in defaults: UserDefaults) {
        let record = ProTrialRecord.starting(at: start)
        defaults.set(record.startedAt.timeIntervalSince1970, forKey: SharedKeys.proTrialStartedAt)
        defaults.set(record.endsAt.timeIntervalSince1970, forKey: SharedKeys.proTrialEndsAt)
    }

    func testTheSnapshotSumsTheTrialsDaysOnly() {
        let defaults = makeDefaults()
        record(500, 60, at: t0.addingTimeInterval(-2 * day), in: defaults)
        mirrorTrial(startingAt: t0, in: defaults)
        record(100, 20, at: t0.addingTimeInterval(day), in: defaults)
        record(200, 40, at: t0.addingTimeInterval(13 * day), in: defaults)
        record(900, 90, at: t0.addingTimeInterval(16 * day), in: defaults)

        let snapshot = ProTrialUsage.snapshot(in: defaults, calendar: utc)
        XCTAssertEqual(snapshot.wordsDictated, 300)
        XCTAssertEqual(snapshot.audioSeconds, 60)
    }

    func testTheSnapshotHasNoDictationWithoutATrial() {
        let defaults = makeDefaults()
        record(100, 20, at: t0, in: defaults)
        XCTAssertEqual(ProTrialUsage.snapshot(in: defaults, calendar: utc), .init(smartModeUses: 0, vocabularyFixes: 0))
    }

    func testARecapWithDictationsAndNoSmartModeIsNotEmpty() {
        let dictated = ProTrialUsage.Snapshot(smartModeUses: 0, vocabularyFixes: 0, wordsDictated: 2_000, audioSeconds: 900)
        XCTAssertFalse(dictated.isEmpty)
        // 2 000 words: 2 297 s of typing, 900 s spoken, 1 397 s saved.
        XCTAssertEqual(dictated.timeSaved, .minutes(23))
        XCTAssertTrue(ProTrialUsage.Snapshot(smartModeUses: 0, vocabularyFixes: 0).isEmpty)
    }

    // MARK: - Non-Gregorian calendars

    /// The user's calendar, as `Calendar.current` hands it over, pinned to UTC.
    private func userCalendar(_ identifier: Calendar.Identifier) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = utc.timeZone
        return calendar
    }

    /// A Buddhist-calendar iPhone (Thailand) is in year 2569; the key stays an ISO day.
    func testABuddhistCalendarStillWritesAndReadsGregorianDays() {
        assertGregorianDays(with: userCalendar(.buddhist))
    }

    /// A Japanese-calendar iPhone is in Reiwa 8, whose string order breaks at the next
    /// era; the key stays an ISO day.
    func testAJapaneseCalendarStillWritesAndReadsGregorianDays() {
        assertGregorianDays(with: userCalendar(.japanese))
    }

    private func assertGregorianDays(with calendar: Calendar,
                                     file: StaticString = #filePath,
                                     line: UInt = #line) {
        let defaults = makeDefaults()
        DictationTally.record(words: 10, audioSeconds: 4, in: defaults, now: t0, calendar: calendar)
        DictationTally.record(words: 20, audioSeconds: 6, in: defaults, now: t0.addingTimeInterval(day), calendar: calendar)

        let stored = defaults.dictionary(forKey: SharedKeys.dictationTally) as? [String: [String: Int]]
        XCTAssertEqual(stored.map { Set($0.keys) }, ["2026-09-21", "2026-09-22"], file: file, line: line)
        // The same keys whichever calendar wrote them, so a user who switches calendar
        // keeps their history.
        XCTAssertEqual(DictationTally.totals(from: t0, through: t0.addingTimeInterval(day), in: defaults, calendar: utc),
                       .init(words: 30, audioSeconds: 10), file: file, line: line)
        // And the recap's window, read in that calendar, finds them.
        mirrorTrial(startingAt: t0, in: defaults)
        XCTAssertEqual(ProTrialUsage.snapshot(in: defaults, calendar: calendar).wordsDictated, 30, file: file, line: line)
    }
}
