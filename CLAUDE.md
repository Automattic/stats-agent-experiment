# Stats agent

Turns natural-language questions about a WordPress.com site's stats into stats calls with Apple's on-device model, and a macOS app that answers them with cards drawn from the site's data.

## Setup

- macOS 26 or later, with Apple Intelligence enabled.
- Xcode's toolchain: the `@Generable` and `@Guide` macros aren't in the Command Line Tools. `xcode-select -p` should point inside `Xcode.app`.
- SwiftPM can't run inside a sandbox, since its own `sandbox-exec` can't nest. Run `swift` and `make` with the sandbox off.

## Map

- `Sources/StatsAgent/`: the model steps. `OptionSelector` picks among options in one call; `CatalogNavigator` descends a catalog, with "none of these" and backtracking; `StatsEndpoints` describes the 21 wordpress-rs stats calls, and `DataCatalog` the same data by what's counted; `CardPicker` holds the app's steps; `StatsAgent` fills in spans and figures, which `StatsPeriods` turns into dates.
- `Sources/StatsAgentApp/`: the macOS app. `JetpackStats/` is copied from the WordPress iOS app and left out of `make format` and SwiftLint.
- `Sources/StatsAgentDatabase/`: the app's SQLite database, through GRDB. `AppDatabase` holds the migrations and the writes; `Records` has a type per table; `Export` reads questions into `ExportV1`, the JSON people share. The schema changes only through a new migration.
- `Plugins/CredentialsPlugin/` and `Sources/generate-credentials/`: compile `wp_com_credentials.json` into the app on every build, as `CompiledCredentials`, with the secret's bytes reversed. Without the file, the app builds and can't log in.
- `Sources/generate-icon/`: draws the app's icon, which `make icon` makes into `Sources/StatsAgentApp/AppIcon.icns`.
- `Sources/stats-agent/`: a command-line tool on the placeholder `Catalog`.
- `Tests/StatsAgentTests/`: the experiments, each writing a file in `results/`, and tests without model calls. Labels are in `StatsQuestionCases` and `DataCatalogLabels`.
- `prompts/raw/`: the question sets the tests read, kept as written.
- `logs/`: feedback logs as JSON lines in `LogEntryV1`'s format, which `FeedbackReportTests` reads, ignored. `sessions/`: output of the command-line tool, ignored.
- `data/`: the database `make run` uses, ignored. The app's own is `Stats agent/stats-agent.sqlite` in Application Support. It holds every question, the agent's decisions, the cards, the stats requests and WordPress.com's responses, the cards looked at and every save of the feedback.

## Commands

- `swift build --build-tests`. `make format` and `make lint` must pass before committing.
- Without model calls, in seconds: `swift test --filter "LogEntryTests|CardPickerTests|StatsPeriodsTests|AppDatabaseTests"`.
- Experiments call the model, take minutes each, and rewrite their file in `results/`. For example, `swift test --filter "OperationStepTests/sightedWithOperations"` runs the main setup in about 5.5 minutes. Add `--no-parallel` when running several suites, or their timings mean nothing.
- `make app` builds the app as a bundle, `.build/app/release/Stats agent.app`, signed with `SIGNING_IDENTITY` or ad hoc without it, with the commit in its `Info.plist`. Its version and build number are `CFBundleShortVersionString` and `CFBundleVersion` in `Sources/StatsAgentApp/Info.plist`. It stops without `wp_com_credentials.json`, the WordPress.com OAuth client the app logs in with, in the package's root; git ignores it, and `wp_com_credentials.json-example` shows its format.
- `make run` builds a debug bundle and opens it, with its database in `data/`.
- `make icon` redraws the app's icon into `Sources/StatsAgentApp/AppIcon.icns`, which is committed and which `make app` copies into the bundle.
- `make previews` draws the window's screens from made-up data, title bar and toolbar included, in light and dark, as PNGs in `.build/previews/`. It doesn't log in, read the keychain, open the database or call the model, so it's the way to look at a UI change from the command line. The screens and their data are in `Previews`. The app keeps its WordPress.com token in the keychain and the site picked in its defaults.
- `swift run stats-agent-app --ask "question"` answers one question with the window hidden, and saves the steps, the log entry and a picture of each card under `.build/screenshots/`. It reads `WORDPRESS_APP_TOKEN`, a WordPress.com OAuth token, and `WORDPRESS_SITE_ID` from its environment.
- `swift run stats-agent` asks questions interactively; `--catalog` lists the catalog.
- `swift test --filter FeedbackReportTests` summarises `logs/` into `results/feedback-report.md`, which is ignored.

## Experiments

- Runs are deterministic: greedy sampling and seeded option orders. After refactoring shared code, rerun one experiment and diff its results file; only the timing line should change.
- Change one thing per run, and commit a results file with the change that produced it.

## Gotchas

- swift-format moves a brace onto its own line when a signature is too long, which SwiftLint's `opening_brace` rejects. Put the parameters one per line.
- `StatsAgent` and `ParameterFiller` cap generation at 200 tokens, because greedy sampling can loop.
- The model can refuse a harmless question with a `LanguageModelError`. Catching it needs `#available(macOS 27.0, *)`.
- An ad hoc signature's designated requirement is the build's hash, so the keychain asks for the token again after each build. `SIGNING_IDENTITY` set to a certificate's identity keeps the requirement the same from one build to the next.
