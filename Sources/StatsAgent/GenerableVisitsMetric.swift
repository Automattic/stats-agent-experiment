import FoundationModels

/// The figure a visits question asks about, decided in a call of its own.
@Generable
public struct GenerableVisitsMetric: Equatable, Sendable {
    @Guide(description: "The figure the question asks about.")
    public var metric: StatsVisitsMetric

    public init(metric: StatsVisitsMetric) {
        self.metric = metric
    }
}

/// A figure the visits call returns per period, among those the app draws.
@Generable
public enum StatsVisitsMetric: Equatable, Sendable {
    case views
    case visitors
    case likes
    case comments
    case posts
}
