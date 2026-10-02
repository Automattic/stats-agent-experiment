import Foundation
import WordPressAPI
import WordPressAPIInternal

/// A WordPress.com site's stats, requested with the token and site from the environment.
///
/// It uses the generated `UniffiWpComApiClient`, because wordpress-rs's `WPComApiClient` has visits as its only stats
/// call.
struct SiteStats: Sendable {
    struct MissingVariable: LocalizedError {
        let name: String

        var errorDescription: String? {
            "Set \(name) in the environment the app starts in."
        }
    }

    struct UnreadablePeriod: LocalizedError {
        let label: String

        var errorDescription: String? {
            "The server labelled a period \"\(label)\", which the app can't read as a date."
        }
    }

    let siteID: WpComSiteId
    /// Kept alongside the client, which is a Rust object and doesn't keep its delegate alive.
    private let delegate: WpApiClientDelegate
    let client: UniffiWpComApiClient

    /// A WordPress.com OAuth token.
    static let tokenVariable = "WORDPRESS_APP_TOKEN"
    static let siteIDVariable = "WORDPRESS_SITE_ID"

    /// Reads the token and the site ID from `tokenVariable` and `siteIDVariable`.
    static func fromEnvironment() throws -> SiteStats {
        let environment = ProcessInfo.processInfo.environment
        guard let token = environment[tokenVariable], !token.isEmpty else {
            throw MissingVariable(name: tokenVariable)
        }
        guard let siteID = environment[siteIDVariable].flatMap(WpComSiteId.init) else {
            throw MissingVariable(name: siteIDVariable)
        }
        let delegate = WpApiClientDelegate(
            authProvider: .staticWithAuth(auth: .bearer(token: token)),
            requestExecutor: WpRequestExecutor(urlSession: .shared),
            middlewarePipeline: .default,
            appNotifier: IgnoredAppNotifier()
        )
        return SiteStats(siteID: siteID, delegate: delegate, client: UniffiWpComApiClient(delegate: delegate))
    }

    /// The request's metric per period, oldest first, each dated to the start of its period in `calendar`. Views,
    /// visitors, likes, comments and posts can be requested; any other metric gets views.
    func visits(_ request: VisitsRequest, calendar: Calendar) async throws -> [DataPoint] {
        let params = StatsVisitsParams(
            unit: Self.unit(for: request.granularity),
            quantity: UInt32(clamping: request.quantity),
            endDate: request.endDate.map { WpDateString(value: $0) }
        )
        let data = try await client.statsVisits()
            .getStatsVisitsCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data
        return try Self.points(data, metric: request.metric, calendar: calendar)
    }

    /// The site's totals, today's and yesterday's figures, its best day, and its views and visitors per day over the
    /// last 30 days.
    func summary(calendar: Calendar) async throws -> SiteSummary {
        let data = try await client.statsSummary()
            .getStatsSummaryCancellation(wpComSiteId: siteID, context: nil)
            .data
        let stats = data.stats
        return SiteSummary(
            views: Int(clamping: stats.views),
            visitors: Int(clamping: stats.visitors),
            posts: Int(clamping: stats.posts),
            comments: Int(clamping: stats.comments),
            followers: Int(clamping: stats.followersBlog),
            viewsToday: Int(clamping: stats.viewsToday),
            viewsYesterday: Int(clamping: stats.viewsYesterday),
            visitorsToday: Int(clamping: stats.visitorsToday),
            visitorsYesterday: Int(clamping: stats.visitorsYesterday),
            bestDay: Self.periodStart(of: stats.viewsBestDay.value, in: calendar),
            bestDayViews: Int(clamping: stats.viewsBestDayTotal),
            dailyViews: try Self.points(data.visits, metric: .views, calendar: calendar),
            dailyVisitors: try Self.points(data.visits, metric: .visitors, calendar: calendar)
        )
    }

    /// The subscriber total at the end of each of `count` periods of `granularity`, the last one holding `lastDay`,
    /// oldest first and each dated to the start of its period in `calendar`. The total counts WordPress.com followers
    /// and email subscribers. Hours aren't offered and fall back to days. Years are labelled by the year alone, which
    /// `periodStart` can't read, so asking for years throws `UnreadablePeriod`.
    func subscribers(
        granularity: DateRangeGranularity,
        count: Int,
        lastDay: Date,
        calendar: Calendar
    ) async throws -> [DataPoint] {
        let params = StatsSubscribersParams(
            unit: Self.subscribersUnit(granularity),
            quantity: UInt32(clamping: count),
            date: WpDateString(value: RankingRequest.day(lastDay, in: calendar)),
            statFields: [.subscribers]
        )
        let data = try await client.statsSubscribers()
            .getStatsSubscribersCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data
        return
            try data.subscribersData()
            .map { point in
                guard let date = Self.periodStart(of: point.period.value, in: calendar) else {
                    throw UnreadablePeriod(label: point.period.value)
                }
                return DataPoint(date: date, value: Int(clamping: point.subscribers))
            }
            .sorted { $0.date < $1.date }
    }

    private static func subscribersUnit(_ granularity: DateRangeGranularity) -> StatsSubscribersUnit {
        switch granularity {
        case .hour, .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }

    /// The start of the period a label names, in `calendar`'s time zone: its year, month and day, and its hour when it
    /// has one. Visits labels follow the unit asked for, `2026-09-21` for a day, `2026W09W21` for the week starting on
    /// that Monday, the first day for a month or year, and `2026-09-21 13:00:00` for an hour. Returns nil for a label in
    /// none of those shapes.
    static func periodStart(of label: String, in calendar: Calendar) -> Date? {
        let numbers = label.split { !$0.isNumber }.compactMap { Int($0) }
        guard numbers.count == 3 || numbers.count == 6 else {
            return nil
        }
        let components = DateComponents(
            year: numbers[0],
            month: numbers[1],
            day: numbers[2],
            hour: numbers.count == 6 ? numbers[3] : 0
        )
        return calendar.date(from: components)
    }

    private static func points(
        _ data: StatsVisitsResponse,
        metric: SiteMetric,
        calendar: Calendar
    ) throws -> [DataPoint] {
        let values: [(period: StatsVisitsPeriod, value: UInt64)] =
            switch metric {
            case .visitors: data.visitorsData().map { ($0.period, $0.visitors) }
            case .likes: data.likesData().map { ($0.period, $0.likes) }
            case .comments: data.commentsData().map { ($0.period, $0.comments) }
            case .posts: data.postsData().map { ($0.period, $0.posts) }
            default: data.visitsData().map { ($0.period, $0.visits) }
            }
        return
            try values
            .map { period, value in
                guard let date = periodStart(of: period.value, in: calendar) else {
                    throw UnreadablePeriod(label: period.value)
                }
                return DataPoint(date: date, value: Int(clamping: value))
            }
            .sorted { $0.date < $1.date }
    }

    private static func unit(for granularity: DateRangeGranularity) -> StatsVisitsUnit {
        switch granularity {
        case .hour: .hour
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }
}

/// What the stats summary call returns, as the app uses it.
struct SiteSummary: Sendable {
    var views: Int
    var visitors: Int
    var posts: Int
    var comments: Int
    var followers: Int
    var viewsToday: Int
    var viewsYesterday: Int
    var visitorsToday: Int
    var visitorsYesterday: Int
    var bestDay: Date?
    var bestDayViews: Int
    var dailyViews: [DataPoint]
    var dailyVisitors: [DataPoint]
}

/// wordpress-rs calls this when a request's authentication is rejected. The app shows the request's error instead.
private final class IgnoredAppNotifier: WpAppNotifier {
    func requestedWithInvalidAuthentication(requestUrl: String) async {}
}
