import Foundation

/// A span of time as whole periods of one unit: `count` periods, ending with the one that holds `lastDay`.
public struct StatsPeriods: Equatable, Sendable {
    public enum Unit: Equatable, Sendable {
        case day
        case week
        case month
        case year

        public var component: Calendar.Component {
            switch self {
            case .day: .day
            case .week: .weekOfYear
            case .month: .month
            case .year: .year
            }
        }
    }

    public var unit: Unit
    /// The start of a day in the last period.
    public var lastDay: Date
    public var count: Int

    public init(unit: Unit, lastDay: Date, count: Int) {
        self.unit = unit
        self.lastDay = lastDay
        self.count = count
    }

    /// From the start of the first period to the end of the last, in `calendar`.
    public func interval(in calendar: Calendar) -> DateInterval? {
        guard let lastPeriod = calendar.dateInterval(of: unit.component, for: lastDay),
            let start = calendar.date(byAdding: unit.component, value: -(count - 1), to: lastPeriod.start)
        else {
            return nil
        }
        return DateInterval(start: start, end: lastPeriod.end)
    }

    /// The same number of periods just before these, such as the whole of October before November.
    public func previous(in calendar: Calendar) -> StatsPeriods? {
        calendar.date(byAdding: unit.component, value: -count, to: lastDay)
            .map {
                StatsPeriods(unit: unit, lastDay: $0, count: count)
            }
    }

    /// The longest span a series gives as days; a longer one is given as months.
    public static let maximumSeriesDays = 92

    /// The span as a series of periods, for a stats call that returns a figure per period, such as subscribers: days
    /// for a span of up to `maximumSeriesDays` days and months for a longer one, ending on the span's last day or
    /// today, whichever is earlier. Nil for a span that starts after today.
    public func series(today: Date, calendar: Calendar) -> StatsPeriods? {
        guard let interval = interval(in: calendar),
            let lastDayOfSpan = calendar.date(byAdding: .day, value: -1, to: interval.end)
        else {
            return nil
        }
        let lastDay = Swift.min(lastDayOfSpan, calendar.startOfDay(for: today))
        guard lastDay >= interval.start,
            let days = calendar.dateComponents([.day], from: interval.start, to: lastDay).day
        else {
            return nil
        }
        if days + 1 <= Self.maximumSeriesDays {
            return StatsPeriods(unit: .day, lastDay: lastDay, count: days + 1)
        }
        guard let firstMonth = calendar.dateInterval(of: .month, for: interval.start)?.start,
            let lastMonth = calendar.dateInterval(of: .month, for: lastDay)?.start,
            let months = calendar.dateComponents([.month], from: firstMonth, to: lastMonth).month
        else {
            return nil
        }
        return StatsPeriods(unit: .month, lastDay: lastDay, count: months + 1)
    }

    /// The series of the span before, to compare with this span's series. When today cuts this span short, such as
    /// this month so far, it's the same stretch of the span before, from its start; otherwise the whole span before.
    public func previousSeries(today: Date, calendar: Calendar) -> StatsPeriods? {
        guard let series = series(today: today, calendar: calendar),
            let interval = interval(in: calendar),
            let lastDayOfSpan = calendar.date(byAdding: .day, value: -1, to: interval.end),
            let before = previous(in: calendar)
        else {
            return nil
        }
        guard series.lastDay < lastDayOfSpan else {
            return before.series(today: today, calendar: calendar)
        }
        let stretch = calendar.dateComponents(
            series.unit == .month ? [.month, .day] : [.day],
            from: interval.start,
            to: series.lastDay
        )
        guard let beforeStart = before.interval(in: calendar)?.start,
            let lastDay = calendar.date(byAdding: stretch, to: beforeStart)
        else {
            return nil
        }
        return StatsPeriods(unit: series.unit, lastDay: lastDay, count: series.count)
    }
}

extension GenerableSpanParams {
    /// The number of days ending today for a question that names no span.
    public static let defaultDays = 30

    /// The span the model named, as periods in `calendar`. A month is the latest one up to this month, unless the year
    /// names an earlier one, and a named year is this one unless the year is earlier: stats can't cover the future, and
    /// the model fills in this year when the question names none. Recent days end today, and are 7 unless the question
    /// says, and at most 365. No span named is the last `defaultDays` days.
    public func periods(today: Date, calendar: Calendar) -> StatsPeriods {
        let today = calendar.startOfDay(for: today)
        let (unit, lastDay, count): (StatsPeriods.Unit, Date?, Int) =
            switch span {
            case .today: (.day, today, 1)
            case .yesterday: (.day, calendar.date(byAdding: .day, value: -1, to: today), 1)
            case .thisWeek: (.week, today, 1)
            case .lastWeek: (.week, calendar.date(byAdding: .day, value: -7, to: today), 1)
            case .thisMonth: (.month, today, 1)
            case .lastMonth: (.month, calendar.date(byAdding: .month, value: -1, to: today), 1)
            case .january, .february, .march, .april, .may, .june, .july, .august, .september, .october, .november,
                .december:
                (.month, namedMonth(calendar: calendar, today: today), 1)
            case .thisYear: (.year, today, 1)
            case .lastYear: (.year, calendar.date(byAdding: .year, value: -1, to: today), 1)
            case .namedYear: (.year, namedYear(calendar: calendar, today: today), 1)
            case .last7Days: (.day, today, 7)
            case .last30Days: (.day, today, 30)
            case .last90Days: (.day, today, 90)
            case .recentDays: (.day, today, Swift.min(Swift.max(days ?? 7, 1), 365))
            case .noSpanNamed: (.day, today, Self.defaultDays)
            }
        return StatsPeriods(unit: unit, lastDay: lastDay ?? today, count: count)
    }

    private func namedMonth(calendar: Calendar, today: Date) -> Date? {
        guard let month = span.month else {
            return today
        }
        let thisYear = calendar.component(.year, from: today)
        let thisMonth = calendar.component(.month, from: today)
        let latestYear = month <= thisMonth ? thisYear : thisYear - 1
        return calendar.date(
            from: DateComponents(year: Swift.min(year ?? latestYear, latestYear), month: month, day: 1)
        )
    }

    private func namedYear(calendar: Calendar, today: Date) -> Date? {
        let thisYear = calendar.component(.year, from: today)
        return calendar.date(from: DateComponents(year: Swift.min(year ?? thisYear, thisYear)))
    }
}
