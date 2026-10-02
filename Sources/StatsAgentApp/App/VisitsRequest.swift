import Foundation

/// A visits request as the app makes it. It sits between the model's parameters, in `StatsAgent`, and the wordpress-rs
/// request, in `SiteStats`, whose types share names.
struct VisitsRequest: Equatable, Sendable {
    var granularity: DateRangeGranularity
    /// How many periods to return, ending on `endDate`.
    var quantity: Int
    /// `YYYY-MM-DD`, or nil for the server's default: today, in the site's time zone.
    var endDate: String?
    var metric: SiteMetric

    /// The parameters in plain words, for a card's path.
    var summary: String {
        let unit = String(describing: granularity)
        let end = endDate.map { "ending \($0)" } ?? "ending today"
        return "\(quantity) \(unit)\(quantity == 1 ? "" : "s"), \(end)"
    }

    /// The parameters as the feedback log records them.
    var logged: [String: String] {
        ["granularity": "\(granularity)", "quantity": "\(quantity)", "endDate": endDate].compactMapValues(\.self)
    }
}
