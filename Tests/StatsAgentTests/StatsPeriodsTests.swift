import Foundation
import StatsAgent
import Testing

/// The dates a span works out to, and the series it becomes, with today on Wednesday 2026-11-18. No model calls.
struct StatsPeriodsTests {
    static let calendar = SpanTests.calendar

    static func today() throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 12)))
    }

    /// The first day of the span `span` and `year` work out to, as `YYYY-MM-DD`.
    static func firstDay(_ span: StatsSpan, year: Int?) throws -> String {
        let params = GenerableSpanParams(span: span, year: year, days: nil, max: nil)
        let interval = try #require(params.periods(today: today(), calendar: calendar).interval(in: calendar))
        return SpanTests.describe(interval).components(separatedBy: "…")[0]
    }

    /// The series `span` becomes, such as `30 days to 2026-11-18`.
    static func series(_ span: StatsSpan) throws -> String {
        let params = GenerableSpanParams(span: span, year: nil, days: nil, max: nil)
        let series = try #require(
            params.periods(today: today(), calendar: calendar).series(today: today(), calendar: calendar)
        )
        let lastDay =
            SpanTests.describe(DateInterval(start: series.lastDay, duration: 86_400))
            .components(separatedBy: "…")[0]
        return "\(series.count) \(series.unit == .day ? "days" : "months") to \(lastDay)"
    }

    /// The series of the span before `span`, such as `18 days to 2026-10-18`.
    static func previousSeries(_ span: StatsSpan) throws -> String {
        let params = GenerableSpanParams(span: span, year: nil, days: nil, max: nil)
        let series = try #require(
            params.periods(today: today(), calendar: calendar).previousSeries(today: today(), calendar: calendar)
        )
        let lastDay =
            SpanTests.describe(DateInterval(start: series.lastDay, duration: 86_400))
            .components(separatedBy: "…")[0]
        return "\(series.count) \(series.unit == .day ? "days" : "months") to \(lastDay)"
    }

    @Test func spanCutAtTodayIsComparedWithTheSameStretchBefore() throws {
        #expect(try Self.previousSeries(.thisWeek) == "3 days to 2026-11-11")
        #expect(try Self.previousSeries(.thisMonth) == "18 days to 2026-10-18")
        #expect(try Self.previousSeries(.thisYear) == "11 months to 2025-11-18")
    }

    @Test func wholeSpanIsComparedWithTheWholeSpanBefore() throws {
        #expect(try Self.previousSeries(.lastMonth) == "30 days to 2026-09-30")
        #expect(try Self.previousSeries(.september) == "31 days to 2026-08-31")
        #expect(try Self.previousSeries(.last30Days) == "30 days to 2026-10-19")
    }

    @Test func seriesOfUpTo92DaysIsDays() throws {
        #expect(try Self.series(.thisWeek) == "3 days to 2026-11-18")
        #expect(try Self.series(.thisMonth) == "18 days to 2026-11-18")
        #expect(try Self.series(.lastMonth) == "31 days to 2026-10-31")
        #expect(try Self.series(.last90Days) == "90 days to 2026-11-18")
    }

    @Test func longerSeriesIsMonths() throws {
        #expect(try Self.series(.thisYear) == "11 months to 2026-11-18")
        #expect(try Self.series(.lastYear) == "12 months to 2025-12-31")
    }

    @Test func monthWithoutYearIsTheLatestOneUpToThisMonth() throws {
        #expect(try Self.firstDay(.november, year: nil) == "2026-11-01")
        #expect(try Self.firstDay(.december, year: nil) == "2025-12-01")
    }

    @Test func monthKeepsAnEarlierYear() throws {
        #expect(try Self.firstDay(.august, year: 2026) == "2026-08-01")
        #expect(try Self.firstDay(.december, year: 2024) == "2024-12-01")
    }

    @Test func monthInTheFutureIsTheLatestOneInstead() throws {
        #expect(try Self.firstDay(.december, year: 2026) == "2025-12-01")
        #expect(try Self.firstDay(.march, year: 2027) == "2026-03-01")
    }

    @Test func namedYearInTheFutureIsThisYear() throws {
        #expect(try Self.firstDay(.namedYear, year: 2025) == "2025-01-01")
        #expect(try Self.firstDay(.namedYear, year: 2027) == "2026-01-01")
        #expect(try Self.firstDay(.namedYear, year: nil) == "2026-01-01")
    }
}
