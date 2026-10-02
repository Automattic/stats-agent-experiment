import Foundation

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
        let name = Names.endpoint(endpoint)
        let path = [name, Names.operation(operation)]
        let range = describe(request, context: context)
        let parameters = "\(request.summary) (asked: \(asked))"
        guard let previous else {
            return Card(
                id: id,
                title: "\(name), \(range)",
                path: path,
                parameters: parameters,
                content: .ranking(list, previous: nil)
            )
        }
        let values = Dictionary(previous.list.rows.map { ($0.name, $0.value) }, uniquingKeysWith: +)
        return Card(
            id: id,
            title: "\(name), \(range) against \(describe(previous.request, context: context))",
            path: path,
            parameters: "\(parameters), against the span before",
            content: .ranking(list, previous: values)
        )
    }

    private static func describe(_ request: RankingRequest, context: StatsContext) -> String {
        request.interval(in: context.calendar).map { context.formatters.dateRange.string(from: $0) } ?? request.summary
    }
}
