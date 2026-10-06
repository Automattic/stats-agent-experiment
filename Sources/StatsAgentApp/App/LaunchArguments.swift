/// The app's command-line arguments: `--ask` for `AskMode`, `--previews` for `Previews`, and `--data-directory` for
/// `Recorder`, which `make run` gives.
enum LaunchArguments {
    /// The argument after `flag`, or nil when `flag` isn't given or is last.
    static func value(after flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}
