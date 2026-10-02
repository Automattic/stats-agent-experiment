# Stats agent

Turns natural-language questions about a WordPress.com site's stats into stats calls with Apple's on-device model, and a macOS app that answers them with cards drawn from the site's data.

## Setup

- macOS 26 or later, with Apple Intelligence enabled.
- Xcode's toolchain: the `@Generable` and `@Guide` macros aren't in the Command Line Tools. `xcode-select -p` should point inside `Xcode.app`.
- SwiftPM can't run inside a sandbox, since its own `sandbox-exec` can't nest. Run `swift` and `make` with the sandbox off.

## Map

- `Sources/StatsAgent/`: the model steps. `OptionSelector` picks among options in one call; `CatalogNavigator` descends a catalog, with "none of these" and backtracking; `StatsEndpoints` describes the 21 wordpress-rs stats calls, and `DataCatalog` the same data by what's counted; `CardPicker` holds the app's steps; `StatsAgent` fills in spans and figures, which `StatsPeriods` turns into dates.
- `Sources/StatsAgentApp/`: the macOS app. `JetpackStats/` is copied from the WordPress iOS app and left out of `make format` and SwiftLint.
- `Sources/stats-agent/`: a command-line tool on the placeholder `Catalog`.
- `Tests/StatsAgentTests/`: the experiments, each writing a file in `results/`, and tests without model calls. Labels are in `StatsQuestionCases` and `DataCatalogLabels`.
- `prompts/raw/`: the question sets the tests read, kept as written.
- `logs/` and `sessions/`: output of the app and the command-line tool, ignored.

## Commands

- `swift build --build-tests`. `make format` and `make lint` must pass before committing.
- Without model calls, in seconds: `swift test --filter "LogEntryTests|CardPickerTests|StatsPeriodsTests"`.
- Experiments call the model, take minutes each, and rewrite their file in `results/`. For example, `swift test --filter "OperationStepTests/sightedWithOperations"` runs the main setup in about 5.5 minutes. Add `--no-parallel` when running several suites, or their timings mean nothing.
- `make run` opens the app. It reads `WORDPRESS_APP_TOKEN`, a WordPress.com OAuth token, and `WORDPRESS_SITE_ID` from its environment, and writes its feedback log to `logs/`. ⌘⇧S saves a screenshot to `.build/screenshots/`.
- `swift run stats-agent-app --ask "question"` answers one question with the window hidden, and saves the steps, the log entry and a picture of each card under `.build/screenshots/`.
- `swift run stats-agent` asks questions interactively; `--catalog` lists the catalog.
- `swift test --filter FeedbackReportTests` summarises `logs/` into `results/feedback-report.md`, which is ignored.

## Experiments

- Runs are deterministic: greedy sampling and seeded option orders. After refactoring shared code, rerun one experiment and diff its results file; only the timing line should change.
- Change one thing per run, and commit a results file with the change that produced it.

## Gotchas

- swift-format moves a brace onto its own line when a signature is too long, which SwiftLint's `opening_brace` rejects. Put the parameters one per line.
- `StatsAgent` and `ParameterFiller` cap generation at 200 tokens, because greedy sampling can loop.
- The model can refuse a harmless question with a `LanguageModelError`. Catching it needs `#available(macOS 27.0, *)`.
