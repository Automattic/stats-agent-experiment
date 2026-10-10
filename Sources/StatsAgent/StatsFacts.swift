import Foundation

/// What a card shows, as short sentences the answer step reads: the figures worked out already, so the model doesn't
/// add up or compare them itself. Spans and days come in as the app writes them, such as "Sep 28 – Oct 4" and "Oct 1".
public enum StatsFacts {
    /// A figure and the day, or other period, it's for.
    public struct Point: Sendable {
        public let value: Int
        public let label: String

        public init(_ value: Int, on label: String) {
            self.value = value
            self.label = label
        }
    }

    /// One item of a ranking, with its figure for the span before when comparing spans.
    public struct Item: Sendable {
        public enum Earlier: Sendable {
            case notCompared
            /// The item wasn't in the span before's list, which can mean it was below that list's cutoff.
            case notListed
            case value(Int)
        }

        public let name: String
        public let value: Int
        public let earlier: Earlier

        public init(_ name: String, _ value: Int, earlier: Earlier = .notCompared) {
            self.name = name
            self.value = value
            self.earlier = earlier
        }
    }

    /// Each card's facts under its title, a fact a line, as the answer step reads them.
    public static func text(_ cards: [(title: String, facts: [String])]) -> String {
        cards.map { card in ([card.title] + card.facts.map { "- \($0)" }).joined(separator: "\n") }
            .joined(separator: "\n\n")
    }

    /// Why visitors over a span aren't added up.
    public static let visitorsNotAddedUp =
        "The stats count each visitor once only within a day, a calendar week or a calendar month, so there is no"
        + " count of different visitors for this span: someone who visited on several days counts once for each."

    /// "Likes, Sep 28 – Oct 4: 88."
    public static func total(_ title: String, _ value: Int) -> String {
        "\(title): \(number(value))."
    }

    /// "Best day: 2,940 (Views on Mar 14, 2025)." With `isChange`, the figure has its sign, such as "+29".
    public static func figure(_ title: String, _ value: Int, detail: String? = nil, isChange: Bool = false) -> String {
        "\(title): \(isChange ? signed(value) : number(value))\(detail.map { " (\($0))" } ?? "")."
    }

    /// "Views, Sep 28 – Oct 4: 2,228. Sep 21 – 27: 1,947. Change: +281 (+14.4%)." With `isChange`, the figures are
    /// changes themselves, written with their signs and not compared: "Change: +29. Aug 6 – Sep 4: +15."
    public static func comparison(
        _ title: String,
        _ value: Int,
        earlier: String,
        _ earlierValue: Int,
        isChange: Bool = false
    ) -> String {
        guard !isChange else {
            return "\(title): \(signed(value)). \(earlier): \(signed(earlierValue))."
        }
        let percent = percentChange(from: earlierValue, to: value).map { " (\($0))" } ?? ""
        return
            "\(title): \(number(value)). \(earlier): \(number(earlierValue)). Change: \(signed(value - earlierValue))"
            + "\(percent)."
    }

    /// "The most in a day: 398 on Oct 1."
    public static func peak(unit: String, _ point: Point) -> String {
        "The most in a \(unit): \(number(point.value)) on \(point.label)."
    }

    /// "Views by day, Sep 5 – Oct 4: 8,062 in all, 268 a day on average, the most 398 on Sep 26, the fewest 187 on
    /// Sep 7." Each part is left out when it's nil.
    public static func series(
        _ title: String,
        unit: String,
        total: Int?,
        average: Int?,
        most: Point?,
        fewest: Point?
    ) -> String {
        let parts = [
            total.map { "\(number($0)) in all" },
            average.map { "\(number($0)) a \(unit) on average" },
            most.map { "the most \(number($0.value)) on \($0.label)" },
            fewest.map { "the fewest \(number($0.value)) on \($0.label)" }
        ]
        .compactMap(\.self)
        return "\(title): \(parts.joined(separator: ", "))."
    }

    /// "Top posts by views, Oct 1 – 4: 1. A Weekend in the Douro Valley, 312. 2. About, 61. All views: 1,288." When
    /// comparing spans, each item says how it changed from the span before, or that it wasn't listed then.
    public static func ranking(
        _ title: String,
        _ items: [Item],
        total: (title: String, value: Int)? = nil,
        isPercentage: Bool = false
    ) -> String {
        guard !items.isEmpty else {
            return "\(title): nothing listed."
        }
        let listed = items.enumerated()
            .map { index, item in
                let value = isPercentage ? "\(item.value)%" : number(item.value)
                let change: String =
                    switch item.earlier {
                    case .notCompared: ""
                    case .notListed: ", not listed in the span before"
                    case .value(let earlier): ", \(signed(item.value - earlier)) on the span before"
                    }
                return "\(index + 1). \(item.name), \(value)\(change)."
            }
        let all = total.map { " \($0.title): \(number($0.value))." } ?? ""
        return "\(title): \(listed.joined(separator: " "))\(all)"
    }

    /// "2,228".
    public static func number(_ value: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_US")))
    }

    /// "+281", "-38" or "0".
    public static func signed(_ value: Int) -> String {
        value > 0 ? "+\(number(value))" : number(value)
    }

    /// "+14.4%" or "-11.8%", to a tenth, or nil when `earlier` is 0.
    public static func percentChange(from earlier: Int, to value: Int) -> String? {
        guard earlier != 0 else {
            return nil
        }
        let percent = (Double(value - earlier) / Double(abs(earlier)) * 1000).rounded() / 10
        let text = percent.rounded() == percent ? String(Int(percent)) : String(percent)
        return "\(percent > 0 ? "+" : "")\(text)%"
    }
}
