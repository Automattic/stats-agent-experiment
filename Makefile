.PHONY: run test experiments prompt-set format lint

# Opens the proof of concept's app, which reads WORDPRESS_APP_TOKEN and WORDPRESS_SITE_ID from the environment it
# starts in, writes the feedback log to logs/, and records the commit it was built from.
run:
	swift run stats-agent-app --log-directory $(CURDIR)/logs --commit $(shell git describe --always --dirty)

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
	swift format --in-place --recursive Package.swift Sources/StatsAgent Sources/stats-agent Sources/StatsAgentApp/App Tests

# SwiftLint runs through the BuildTools package plugin, pinned to `swiftlint_version` in .swiftlint.yml.
lint:
	swift package --package-path BuildTools plugin \
		--allow-writing-to-directory $(CURDIR) --allow-writing-to-package-directory \
		swiftlint --working-directory $(CURDIR) --quiet $(CURDIR)/Sources $(CURDIR)/Tests
