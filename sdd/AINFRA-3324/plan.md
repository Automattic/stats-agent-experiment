# Plan — AINFRA-3324

Source of truth: `spec.md`. Tasks 1–8 belong to the app implementer; tasks 9–10 belong to the parent. Each checkbox is an independently verifiable increment. Baseline formatting, lint, compilation, and 30 deterministic tests already pass.

- [x] **1. Pin the CI tools and signing dependency.**
  - **Files:** `.xcode-version`, `.ruby-version`, `Gemfile`, `Gemfile.lock`, `.gitignore`.
  - **Do:** Pin Xcode 27.0, Ruby 3.4.9, and fastlane; generate the Bundler lockfile; ignore local Bundler/fastlane output.
  - **Accept:** Bundler resolves the committed lockfile; no unpinned fastlane dependency or generated output is tracked.
  - **Dependencies:** none.

- [x] **2. Expose deterministic and non-mutating checks.**
  - **Files:** `Makefile`, `.buildkite/commands/lint.sh`, `.buildkite/commands/build-and-test.sh`.
  - **Do:** Add format-check and deterministic-test targets using the existing source scope and four documented suites. Add executable CI wrappers for formatting/lint and building all tests before running deterministic suites.
  - **Accept:** Shell syntax passes; commands exclude model experiments and preserve existing local commands.
  - **Dependencies:** none.

- [x] **3. Extend app packaging for distribution.**
  - **Files:** `Makefile`.
  - **Do:** Add optional signing flags and copy SwiftPM dependency resource bundles into `Contents/Resources` before signing. Keep ad hoc signing as the default and allow release to select arm64 explicitly.
  - **Accept:** A fixture-credential `make app` produces a valid ad hoc app with GRDB resources; hardened-runtime/timestamp flags can be passed without altering local defaults.
  - **Dependencies:** 2.

- [x] **4. Guard releases and stage OAuth credentials safely.**
  - **Files:** `.buildkite/commands/release.sh`, `.buildkite/commands/write-credentials.rb`.
  - **Do:** Reject non-version tags and app-version mismatches before credential preparation. Validate positive integer client ID/nonempty secret, serialize JSON with mode 0600, refuse an existing credentials file, and clean up the newly created file on success/failure.
  - **Accept:** Stubbed executions cover branches, unrelated/mismatched tags, invalid/missing inputs, existing files, JSON escaping, and cleanup without printing secrets or invoking signing for invalid tags.
  - **Dependencies:** 1.

- [x] **5. Synchronize the Developer ID certificate.**
  - **Files:** `fastlane/Fastfile`, `.buildkite/commands/release.sh`.
  - **Do:** Add a release lane using `setup_ci` and read-only S3 `sync_code_signing` for team `PZYM8XX95Q`, Developer ID, macOS, and no provisioning profiles. Validate required environment variables and invoke arm64 `make app` with a Developer ID identity, hardened runtime, and timestamp.
  - **Accept:** Ruby/shell syntax passes; configuration matches the spec and missing credentials cannot fall back to ad hoc release signing.
  - **Dependencies:** 1, 3, 4.

- [x] **6. Notarize, verify, and upload the finished ZIP.**
  - **Files:** `fastlane/Fastfile`, `.buildkite/commands/release.sh`.
  - **Do:** Map `APP_STORE_CONNECT_API_KEY_KEY` explicitly into the API key action. Notarize/staple the app, verify codesign/stapler/Gatekeeper, then create a versioned arm64 ZIP with `ditto` under `.build/` and explicitly upload that artifact.
  - **Accept:** A failed signing/notarization/verification stage prevents final ZIP upload; no intermediate archive or credential file is uploaded. Actual Apple verification remains a rollout check.
  - **Dependencies:** 5.

- [x] **7. Connect the Buildkite steps.**
  - **Files:** `.buildkite/pipeline.yml`, `.buildkite/shared-pipeline-vars`.
  - **Do:** Pin the supported Mac image and CI toolkit plugin. Configure mac-queue checks with finite timeouts and explicit GitHub contexts; release depends on both checks and runs only for `vMAJOR.MINOR.PATCH` tags.
  - **Accept:** Raw and environment-rendered YAML validate against Buildkite's schema; dependencies, tag guard, image, plugin, and status contexts are present.
  - **Dependencies:** 2, 6.

- [x] **8. Document download, release, and setup procedures.**
  - **Files:** `README.md`, `.buildkite/README.md`, `CLAUDE.md`.
  - **Do:** Explain artifact download and runtime requirements; document commands, version/tag matching, exact OAuth/match/App Store Connect variables, pipeline secret namespace, deploy-key/webhook setup, and the reviewed Terraform deployment process.
  - **Accept:** Instructions distinguish locally validated implementation from pending provisioning, secret installation, first signed tag build, and downloaded-app login checks. No credentials are included.
  - **Dependencies:** 7.

- [x] **9. Prepare the companion pipeline registration.**
  - **Owner:** parent.
  - **Files:** `/tmp/stats-agent-ainfra-3324-buildkite-ci/src/buildkite/pipelines/stats-agent-experiment.tf`.
  - **Do:** Follow the companion repository's `buildkite-pipelines` skill: standard upload template, mac/WordPress/app tags, everyone/admin bindings, PR/trunk/tag filter, no forks or implicit statuses, and intermediate-build filters excluding trunk. Keep policy-required rebuild settings disabled.
  - **Accept:** Terraform formatting and available policy checks pass; document unavailable credential/Docker-dependent checks. Do not apply shared infrastructure or commit.
  - **Dependencies:** none.

- [x] **10. Validate and independently review the complete change.**
  - **Owner:** parent.
  - **Files:** `sdd/AINFRA-3324/implementation-notes.md`, `sdd/AINFRA-3324/plan.md`; fixes in exact implementation files above as needed.
  - **Do:** Run format, non-mutating format check, lint, build-all-tests, and the four deterministic suites; perform syntax/schema, release-guard/cleanup, and fixture-app checks. Obtain independent review and resolve findings. Record evidence, deviations, and remaining operational checks; update completed task checkboxes.
  - **Accept:** Required local checks pass, no model experiment results or credentials enter the diff, review findings are resolved, and real signing/provisioning limitations are explicit. No tag creation, infrastructure apply, or commits.
  - **Dependencies:** 8, 9.
