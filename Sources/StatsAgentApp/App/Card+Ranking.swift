import Foundation
import StatsAgent

extension Card {
    /// A card for `endpoint`, a stats call that ranks items, from `list` as fetched for `request`. `asked` is the span
    /// the model named, in plain words, which the path shows after the request. When comparing periods, `previous` is
    /// the same call for the span before.
    static func ranking(
        id: Int,
        endpoint: String,
        operation: String,
        request: RankingRequest,
        asked: String,
        list: RankedList,
        previous: (list: RankedList, request: RankingRequest)?,
        context: StatsContext
    ) -> Card {
        let name = DisplayNames.endpoint(endpoint)
        let path = [name, DisplayNames.operation(operation)]
        let range = describe(request, context: context)
        let parameters = "\(request.summary) (asked: \(asked))"
        guard let previous else {
            return Card(
                id: id,
                title: "\(name), \(range)",
                path: path,
                parameters: parameters,
                content: .ranking(list, previous: nil),
                facts: [rankingFact(name, range, list, earlier: nil)]
            )
        }
        let values = Dictionary(previous.list.rows.map { ($0.name, $0.value) }, uniquingKeysWith: +)
        return Card(
            id: id,
            title: "\(name), \(range) against \(describe(previous.request, context: context))",
            path: path,
            parameters: "\(parameters), against the span before",
            content: .ranking(list, previous: values),
            facts: [rankingFact(name, range, list, earlier: values)]
        )
    }

    /// "Top posts by views, Oct 1 – 4: 1. A Weekend in the Douro Valley, 312. All views, listed or not: 1,288.", with
    /// each item's change from `earlier`, the figures of the span before, when comparing spans.
    private static func rankingFact(
        _ name: String,
        _ range: String,
        _ list: RankedList,
        earlier: [String: Int]?
    ) -> String {
        let metric = list.metricTitle.lowercased()
        let items = list.rows.map { row in
            let change: StatsFacts.Item.Earlier =
                earlier.map { values in values[row.name].map { .value($0) } ?? .notListed } ?? .notCompared
            return StatsFacts.Item(row.name, row.value, earlier: change)
        }
        return StatsFacts.ranking(
            "\(name) by \(metric), \(range)",
            items,
            total: list.total,
            metric: metric,
            isPercentage: list.isPercentage
        )
    }

    private static func describe(_ request: RankingRequest, context: StatsContext) -> String {
        request.interval(in: context.calendar).map { context.formatters.dateRange.string(from: $0) } ?? request.summary
    }
}
