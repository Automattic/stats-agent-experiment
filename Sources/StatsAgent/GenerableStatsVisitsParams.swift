import FoundationModels

/// The parameters of the wordpress-rs `StatsVisitsParams` request, in a form the on-device model can generate.
///
/// The guide descriptions are the doc comments in wordpress-rs `wp_api/src/wp_com/stats_visits.rs`.
@Generable
public struct GenerableStatsVisitsParams: Equatable, Sendable {
    @Guide(description: "The time unit for grouping visits.")
    public var unit: StatsVisitsUnit?

    @Guide(description: "The number of time units to return.")
    public var quantity: Int?

    @Guide(description: "The end date to query stats for (format: YYYY-MM-DD).")
    public var endDate: String?

    @Guide(description: "The start date to query stats for (format: YYYY-MM-DD).")
    public var startDate: String?

    @Guide(
        description:
            "The specific stat fields to include in the response. When empty, the API returns its default set of fields."
    )
    public var statFields: [StatsVisitsField]

    public init(
        unit: StatsVisitsUnit?,
        quantity: Int?,
        endDate: String?,
        startDate: String?,
        statFields: [StatsVisitsField]
    ) {
        self.unit = unit
        self.quantity = quantity
        self.endDate = endDate
        self.startDate = startDate
        self.statFields = statFields
    }
}

/// The time unit for grouping visits.
@Generable
public enum StatsVisitsUnit: Equatable, Sendable {
    case day
    case hour
    case week
    case month
    case year
}

/// A stat field that can be requested from the stats visits endpoint.
@Generable
public enum StatsVisitsField: Equatable, Sendable {
    case views
    case visitors
    case likes
    case reblogs
    case comments
    case posts
}
