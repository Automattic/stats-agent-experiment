.PHONY: app run previews icon test test-deterministic experiments prompt-set format format-check lint

CONFIGURATION ?= release
APP = .build/app/$(CONFIGURATION)/Stats agent.app
# The identity the app is signed with, such as an "Apple Development" one from `security find-identity -v -p
# codesigning`. Ad hoc by default, which makes the signature's designated requirement the build's hash, so the
# keychain's Always Allow for the token lasts until the next build.
SIGNING_IDENTITY ?= -
# Distribution builds select arm64 and enable hardened runtime with a secure timestamp. Local defaults stay ad hoc.
ARCH ?=
SWIFT_ARCH_FLAGS = $(if $(ARCH),--arch $(ARCH))
SIGNING_FLAGS ?=

FORMAT_SOURCES = Package.swift Sources/StatsAgent Sources/stats-agent Sources/StatsAgentApp/App \
	Sources/StatsAgentDatabase Sources/generate-credentials Sources/generate-icon Plugins Tests

# Builds the proof of concept's app as a bundle, .build/app/release/Stats agent.app, with its icon, signed with
# SIGNING_IDENTITY. Its Info.plist records the commit it was built from. It stops without wp_com_credentials.json, the
# WordPress.com OAuth client the app logs in with, which CredentialsPlugin compiles in.
app:
	@test -f wp_com_credentials.json || { echo "make app needs wp_com_credentials.json in $(CURDIR)."; exit 1; }
	swift build --configuration $(CONFIGURATION) $(SWIFT_ARCH_FLAGS) --product stats-agent-app
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$$(swift build --configuration $(CONFIGURATION) $(SWIFT_ARCH_FLAGS) --show-bin-path)/stats-agent-app" "$(APP)/Contents/MacOS/"
	@for bundle in "$$(swift build --configuration $(CONFIGURATION) $(SWIFT_ARCH_FLAGS) --show-bin-path)"/*.bundle; do \
		[ ! -d "$$bundle" ] || cp -R "$$bundle" "$(APP)/Contents/Resources/" || exit 1; \
	done
	cp Sources/StatsAgentApp/Info.plist "$(APP)/Contents/"
	cp Sources/StatsAgentApp/AppIcon.icns "$(APP)/Contents/Resources/"
	plutil -insert StatsAgentCommit -string "$$(git describe --always --dirty)" "$(APP)/Contents/Info.plist"
	codesign --force --sign "$(SIGNING_IDENTITY)" $(SIGNING_FLAGS) "$(APP)"

# Builds the app as a debug bundle, .build/app/debug/Stats agent.app, and runs it from here, with its database in data/.
run: CONFIGURATION = debug
run: app
	"$(APP)/Contents/MacOS/stats-agent-app" --data-directory $(CURDIR)/data

# Draws the window's screens from made-up data, in light and dark, as PNGs in .build/previews/, without logging in,
# reading the keychain, opening the database or calling the model.
previews:
	rm -rf $(CURDIR)/.build/previews
	swift run stats-agent-app --previews $(CURDIR)/.build/previews

# Draws the app's icon with generate-icon and makes it into Sources/StatsAgentApp/AppIcon.icns, which make app copies
# into the bundle. The .icns is committed, so this runs only when the drawing changes.
icon:
	rm -rf $(CURDIR)/.build/AppIcon.iconset
	swift run generate-icon $(CURDIR)/.build/AppIcon.iconset
	iconutil --convert icns --output Sources/StatsAgentApp/AppIcon.icns $(CURDIR)/.build/AppIcon.iconset

test:
	swift test

# These suites do not call Apple Intelligence or rewrite experiment results.
test-deterministic:
	swift test --filter 'CardPickerTests|StatsPeriodsTests|AppDatabaseTests|FeedbackReportTests'

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
	swift format --in-place --recursive $(FORMAT_SOURCES)

format-check:
	swift format lint --strict --recursive $(FORMAT_SOURCES)

# SwiftLint runs through the BuildTools package plugin, pinned to `swiftlint_version` in .swiftlint.yml.
lint:
	swift package --package-path BuildTools plugin \
		--allow-writing-to-directory $(CURDIR) --allow-writing-to-package-directory \
		swiftlint --working-directory $(CURDIR) --quiet $(CURDIR)/Sources $(CURDIR)/Plugins $(CURDIR)/Tests
