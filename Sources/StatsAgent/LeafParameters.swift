extension ParameterFiller {
    /// Fills in the parameters of `leaf` from the question, as names and values for display and logging.
    /// Returns nil for leaves that have no parameters.
    public func parameters(of leaf: CatalogNode, for question: String) async throws -> [String: String]? {
        switch leaf.id {
        case "stats_on_day":
            let parameters = try await fill(DayStatsParameters.self, for: question, task: leaf.description)
            return ["metric": "\(parameters.metric)"]
        default:
            return nil
        }
    }
}
