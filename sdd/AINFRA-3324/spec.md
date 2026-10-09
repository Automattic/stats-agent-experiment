# Spec: Buildkite integration and signed macOS builds

## Goal

Build and check Stats agent on Buildkite, and provide colleagues with a signed, notarized macOS app ZIP for each version tag. Preserve the existing SwiftPM development workflow.

## Requirements Summary

CI checks pull requests, trunk, and tags. Distribution runs only for version tags after checks pass. The app includes WordPress.com OAuth client 133791, uses Automattic's Developer ID certificate, and is notarized and stapled before upload. Credentials remain in the existing CI secret store. The companion pipeline registration is managed through buildkite-ci Terraform.

## Chosen Approach

**SwiftPM with minimal fastlane**, selected by the user. Keep building and bundling through the Makefile. Fastlane supplies read-only S3 match certificate synchronization and Apple's notarization workflow, following Studio and Cortext. No release-toolkit plugin is needed for this small set of built-in actions.

### Alternatives Considered

- Standalone shell signing: fewer dependencies, but requires maintaining certificate download/decryption, keychain import, and notarization handling. The user selected fastlane.
- Adding an Xcode project: unnecessary migration for a SwiftPM app; retain the established build path.

## Technical Details

### Pipeline

- Pin `.xcode-version` to `27.0` and `.ruby-version` to `3.4.9`, available in Automattic's image manifest. Xcode 27 compiles the macOS 27 API references while retaining the app's macOS 26 deployment target.
- Use `.buildkite/shared-pipeline-vars` to export `IMAGE_ID` and the pinned Automattic CI toolkit plugin.
- Run a formatting/lint step and a build/test step on `queue: mac`, with explicit GitHub status contexts and finite timeouts.
- Build all targets/tests, then run the four deterministic suites documented in CLAUDE.md. Do not run model experiments.
- Add a release step depending on both checks, guarded by `build.tag` matching `vMAJOR.MINOR.PATCH`. Use the same guard in the release entrypoint and verify its version equals `CFBundleShortVersionString` before preparing credentials. Branch builds and unrelated tags must never sign or upload an app.
- Name the final ZIP with the version and arm64 architecture. Use explicit artifact upload after all verification succeeds, avoiding automatic upload of a failed or unstapled intermediate archive.

### Packaging and Signing

- Preserve ad hoc local signing. Add explicit signing flags to `make app` so CI can pass `--options runtime --timestamp` with a Developer ID Application identity.
- Package dependency resource bundles (currently GRDB's privacy manifest) in `Contents/Resources` before signing.
- Use `setup_ci` for CI keychain setup, and `sync_code_signing` with `readonly: true`, `type: developer_id`, `platform: macos`, Automattic team `PZYM8XX95Q`, and S3 bucket `a8c-fastlane-match` in `us-east-2`. Skip provisioning profiles: this app has no capabilities requiring them.
- Use a pinned fastlane dependency and commit the generated Bundler lockfile.
- Run Apple's notarization through fastlane's built-in action with App Store Connect API credentials. Notarize the `.app`, allowing fastlane to staple it. Verify codesign, stapler, and Gatekeeper before creating the final ZIP with `ditto`.
- Keep all staging output under ignored `.build/`; do not upload raw credential files or intermediate notarization ZIPs.

### Credentials

- CI provides the WordPress.com client secret and ID through environment variables. Generate the JSON with a real JSON serializer; validate a positive integer ID and nonempty secret. Write with restrictive permissions, never echo credentials, and clean up on success/failure. Refuse to overwrite a pre-existing local credentials file.
- Document the exact environment variable contract for OAuth, S3 match, and App Store Connect. The fastlane action's key content parameter must be explicitly mapped from Automattic's `APP_STORE_CONNECT_API_KEY_KEY` convention.
- Ordinary checks compile without OAuth credentials. Missing release credentials fail clearly; never fall back to ad hoc release signing.

### Pipeline Registration

- Add `src/buildkite/pipelines/stats-agent-experiment.tf` in a separate buildkite-ci checkout using `local.defaults.pipeline_upload_steps` and standard team bindings.
- Build internal PRs, trunk, and tags; disable fork builds and implicit commit statuses. Cancel/skip intermediate branch builds except trunk.
- Validate formatting and available policy checks. Follow buildkite-ci's reviewed Terraform deployment process; do not apply infrastructure here.
- Document remaining deploy-key, webhook, and `mobile-secrets` setup, plus a first tagged CI validation.

### File Changes

| File | Change | Purpose |
| --- | --- | --- |
| `.buildkite/pipeline.yml`, `shared-pipeline-vars` | New | CI checks and tag-only release dependency graph |
| `.buildkite/commands/*` | New | Build/test, lint, and release entrypoints as needed |
| `.xcode-version`, `.ruby-version` | New | Pin CI toolchain |
| `Gemfile`, `Gemfile.lock`, `fastlane/Fastfile` | New | Minimal signing and notarization |
| `Makefile` | Modify | Distribution flags, resource bundles, reusable deterministic/check-format targets |
| `.gitignore` | Modify | Ignore Bundler and fastlane local output |
| `README.md`, `.buildkite/README.md`, `CLAUDE.md` | Modify/new | Download/release/setup instructions and command map |
| buildkite-ci `src/buildkite/pipelines/stats-agent-experiment.tf` | New | Register pipeline and access |

### Validation

Run `make format`, non-mutating format check, `make lint`, `swift build --build-tests`, and deterministic tests. Validate raw/rendered pipeline YAML against Buildkite's schema. Exercise release guards and cleanup with fake credentials and stubbed external commands where appropriate. Build a local ad hoc app with fixture OAuth credentials and verify its bundle/signature/resources. Independently review changes. Actual Developer ID signing, notarization, and first downloaded-app login remain CI rollout checks requiring credentials and provisioned infrastructure.

## Out of Scope

GitHub publishing, App Store/TestFlight, auto-updates, Intel/iOS packaging, model experiments in CI, application feature changes, and automatic Terraform deployment.

## Open Questions Resolved

- User chose full feature workflow, version-tag-only releases, Buildkite ZIP artifacts, and minimal fastlane.
- Tags use the conventional `vMAJOR.MINOR.PATCH` format and must match the existing app version; no version bump or tag creation is part of implementation.
- Baseline validation passed: formatting, SwiftLint, build, and 30 deterministic tests. The build emits an existing SwiftUI `@Entry` closure warning in `ExportView.swift`.
