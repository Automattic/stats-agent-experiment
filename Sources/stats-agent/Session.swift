import Foundation
import StatsAgent

/// Runs one prompt through the navigator and parameter step, prints each step, and logs the exchange.
struct Session {
    let log: ExchangeLog
    private let navigator = CatalogNavigator()
    private let filler = ParameterFiller()

    init(log: ExchangeLog) {
        self.log = log
    }

    /// When `interactive`, asks whether the result would answer the question and, if not, what was expected.
    func ask(_ prompt: String, interactive: Bool) async {
        let clock = ContinuousClock()
        let start = clock.now
        var exchange = Exchange(prompt: prompt)
        do {
            let attempts = try await navigator.navigate(prompt)
            exchange.attempts = attempts.map(Exchange.Attempt.init)
            exchange.result = attempts.last?.leaf?.id
            write(Self.describe(attempts))
            if let leaf = attempts.last?.leaf {
                let parameterStart = clock.now
                if let parameters = try await filler.parameters(of: leaf, for: prompt) {
                    let duration = clock.now - parameterStart
                    exchange.parameters = parameters
                    exchange.parameterSeconds = duration.seconds
                    let values = parameters.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
                    write(
                        "    \(pad("parameters", 10)) \(pad(values.joined(separator: ", "), 44))  \(duration.formatted)\n"
                    )
                }
            }
            let total = clock.now - start
            exchange.totalSeconds = total.seconds
            write("  → \(Self.summary(of: attempts, parameters: exchange.parameters)) in \(total.formatted)\n")
        } catch {
            exchange.error = "\(error)"
            write("  error: \(error)\n")
        }

        if interactive, exchange.error == nil {
            let question = "  y: answers it, p: right place but wouldn't answer it, n: wrong [return to skip] "
            switch readAnswer(after: question)?.lowercased() {
            case "y", "yes":
                exchange.verdict = "answers"
            case "p":
                exchange.verdict = "relevant"
                exchange.expected = Self.readExpected()
            case "n", "no":
                exchange.verdict = "wrong"
                exchange.expected = Self.readExpected()
            default:
                break
            }
        }
        do {
            try log.append(exchange)
        } catch {
            write("  couldn't write to the log: \(error)\n")
        }
        write("\n")
    }

    private static func readExpected() -> String? {
        let expected = readAnswer(after: "  what did you expect? [return to skip] ")
        return expected?.isEmpty == false ? expected : nil
    }

    static func describe(_ attempts: [CatalogNavigator.Attempt]) -> String {
        attempts.enumerated()
            .map { index, attempt in
                let leafName = attempt.leaf?.id ?? "none of these"
                var lines = [
                    attempts.count > 1 ? "  attempt \(index + 1)" : nil,
                    row("area", attempt.branch.id, attempt.branchStep),
                    row("leaf", leafName, attempt.leafStep)
                ]
                if let leaf = attempt.leaf {
                    lines.append("    \(pad("", 10)) \(leaf.description)")
                }
                return lines.compactMap { $0 }.joined(separator: "\n") + "\n"
            }
            .joined()
    }

    static func summary(of attempts: [CatalogNavigator.Attempt], parameters: [String: String]?) -> String {
        guard let last = attempts.last, let leaf = last.leaf else {
            return "no match: \"none of these\" in every area tried"
        }
        let values = (parameters ?? [:]).sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }
        return "\(last.branch.id) › \(leaf.id)" + (values.isEmpty ? "" : " (\(values.joined(separator: ", ")))")
    }

    private static func row(_ label: String, _ choice: String, _ step: CatalogNavigator.Step) -> String {
        "    \(pad(label, 10)) \(pad(choice, 24)) of \(pad(step.optionCount, 2)) options   \(step.duration.formatted)"
    }
}

/// Left-aligns `value` in a column `width` characters wide.
func pad(_ value: some CustomStringConvertible, _ width: Int) -> String {
    let text = value.description
    return text + String(repeating: " ", count: max(0, width - text.count))
}
