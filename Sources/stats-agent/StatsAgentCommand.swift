import Foundation
import FoundationModels
import StatsAgent

/// Try prompts against the catalog by hand and see each step the model takes.
///
///     swift run stats-agent                                  # ask interactively
///     swift run stats-agent How many views did I get today?  # ask once
///     swift run stats-agent --catalog                        # list everything the catalog holds
///     swift run stats-agent --log path/to/file.jsonl         # log somewhere other than sessions/
///
/// Every exchange is appended to a JSON Lines log, `sessions/<date>.jsonl` in the current directory by default.
@main
struct StatsAgentCommand {
    static func main() async {
        var arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--catalog") {
            write(catalogListing())
            return
        }
        var log = ExchangeLog.forToday()
        if let index = arguments.firstIndex(of: "--log"), arguments.indices.contains(index + 1) {
            log = ExchangeLog(url: URL(filePath: arguments[index + 1]))
            arguments.removeSubrange(index...index + 1)
        }
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            write("The on-device model is unavailable: \(reason)\n")
            exit(1)
        }

        let session = Session(log: log)
        if !arguments.isEmpty {
            await session.ask(arguments.joined(separator: " "), interactive: false)
            return
        }
        write(
            """
            Ask something, for example: How many likes did my posts get yesterday?
            :catalog lists everything the catalog holds. :quit or Ctrl-D leaves.
            Exchanges are saved to \(log.url.path(percentEncoded: false))

            """
        )
        while true {
            write("> ")
            guard let line = readLine() else {
                write("\n")
                break
            }
            let prompt = line.trimmingCharacters(in: .whitespaces)
            switch prompt {
            case "":
                continue
            case ":quit":
                return
            case ":catalog":
                write(catalogListing())
            default:
                await session.ask(prompt, interactive: true)
            }
        }
    }

    static func catalogListing() -> String {
        Catalog.root
            .map { branch in
                let leaves = branch.children.map { "    \($0.id): \($0.description)" }
                return (["\(branch.id): \(branch.description)"] + leaves).joined(separator: "\n")
            }
            .joined(separator: "\n\n") + "\n"
    }
}

/// Writes straight to standard output, so prompts without a newline appear immediately.
func write(_ text: String) {
    FileHandle.standardOutput.write(Data(text.utf8))
}

/// Reads a line after showing `prompt`, or returns nil at end of input.
func readAnswer(after prompt: String) -> String? {
    write(prompt)
    return readLine()?.trimmingCharacters(in: .whitespaces)
}

extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    var formatted: String {
        String(format: "%.2f s", seconds)
    }
}
