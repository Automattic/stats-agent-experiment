.PHONY: app run test experiments prompt-set format lint

CONFIGURATION ?= release
APP = .build/app/$(CONFIGURATION)/Stats agent.app

# Builds the proof of concept's app as a bundle, .build/app/release/Stats agent.app, signed ad hoc. Its Info.plist
# records the commit it was built from. It stops without wp_com_credentials.json, the WordPress.com OAuth client the
# app logs in with, which CredentialsPlugin compiles in.
app:
	@test -f wp_com_credentials.json || { echo "make app needs wp_com_credentials.json in $(CURDIR)."; exit 1; }
	swift build --configuration $(CONFIGURATION) --product stats-agent-app
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	cp "$$(swift build --configuration $(CONFIGURATION) --show-bin-path)/stats-agent-app" "$(APP)/Contents/MacOS/"
	cp Sources/StatsAgentApp/Info.plist "$(APP)/Contents/"
	plutil -insert StatsAgentCommit -string "$$(git describe --always --dirty)" "$(APP)/Contents/Info.plist"
	codesign --force --sign - "$(APP)"

# Builds the app as a debug bundle, .build/app/debug/Stats agent.app, and runs it from here, writing the feedback log
# to logs/ and its database to data/.
run: CONFIGURATION = debug
run: app
	"$(APP)/Contents/MacOS/stats-agent-app" --log-directory $(CURDIR)/logs --data-directory $(CURDIR)/data

test:
	swift test

# Runs the selection experiments on the original prompts one suite at a time. `swift test` runs suites in parallel,
# which makes the timings in the results files meaningless. Every miss is a test issue, so each run exits non-zero;
# the leading `-` keeps make going to the next one.
experiments:
	-swift test --filter FlatSelectionTests/flatSelection
	-swift test --filter PyramidSelectionTests/pyramidSelection
	-swift test --filter BacktrackingSelectionTests/pyramidWithBacktracking

# Runs the selection experiments on prompts/raw/$(PROMPTS).md, for example `make prompt-set PROMPTS=paraphrases-round-1`.
prompt-set:
	$(if $(PROMPTS),,$(error Set PROMPTS to a file name in prompts/raw without .md))
	PROMPTS=$(PROMPTS) swift test --filter PromptSetTests

# Sources/StatsAgentApp/JetpackStats is copied from the WordPress iOS app and keeps its own formatting, so it's left
# out here and in .swiftlint.yml.
format:
	swift format --in-place --recursive Package.swift Sources/StatsAgent Sources/stats-agent Sources/StatsAgentApp/App \
		Sources/StatsAgentDatabase Sources/generate-credentials Plugins Tests

# SwiftLint runs through the BuildTools package plugin, pinned to `swiftlint_version` in .swiftlint.yml.
lint:
	swift package --package-path BuildTools plugin \
		--allow-writing-to-directory $(CURDIR) --allow-writing-to-package-directory \
		swiftlint --working-directory $(CURDIR) --quiet $(CURDIR)/Sources $(CURDIR)/Plugins $(CURDIR)/Tests
