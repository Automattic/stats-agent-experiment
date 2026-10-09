# AINFRA-3324 — Requirements

## Goal

Let Automatticians download and run the Stats agent experiment without building or signing it themselves. Add repeatable Buildkite checks and signed macOS distribution builds.

## Requirements

1. Run formatting, lint, compilation, and deterministic tests on pull requests and trunk.
2. Produce signed distribution builds only on version tags, after those checks pass.
3. Build an Apple Silicon macOS app containing the WordPress.com OAuth client for app 133791.
4. Sign with Automattic's Developer ID Application certificate, enable hardened runtime and secure timestamps, notarize with Apple, and staple the ticket.
5. Verify the finished app and upload a ZIP as a Buildkite artifact for colleagues to download.
6. Preserve local `make run` and `make app` behavior, including ad hoc signing by default.
7. Keep credentials in Automattic's existing CI secret store; do not commit or log them.
8. Prepare the companion Terraform registration in buildkite-ci and document setup and artifact use.

## Constraints

- Existing SwiftPM package and macOS 26 minimum runtime. Apple Intelligence is needed to use the app.
- Use full Xcode: the Foundation Models macros are unavailable in Command Line Tools. The tests reference macOS 27 SDK symbols, so CI needs Xcode 27.
- Build all tests, but execute only the non-model suites documented in CLAUDE.md. Model experiments require Apple Intelligence and rewrite checked-in results.
- Pipeline configuration follows Automattic's queue/image/plugin and Terraform conventions.
- Pipeline provisioning, secret installation, webhook/deploy-key setup, and an actual signed CI run must be distinguished from locally validated code.

## Out of Scope

- GitHub Release publishing, App Store/TestFlight distribution, auto-updates, DMGs, Intel builds, and iOS builds.
- Changes to the agent, application UI, experiments, or dependency versions.
- Automatically applying shared infrastructure changes.

## Open Questions

- Operational setup will need the OAuth client's actual secret and existing signing/notarization credentials in the pipeline's secret namespace.

## Related Code / Patterns Found

- `Makefile`: packages the app and supports `SIGNING_IDENTITY`; lacks hardened runtime/timestamp distribution options.
- `Plugins/CredentialsPlugin/CredentialsPlugin.swift` and `Sources/generate-credentials/main.swift`: compile root `wp_com_credentials.json` into the app.
- `Sources/StatsAgentApp/Info.plist`: bundle identifier `com.automattic.stats-agent`, version/build fields, minimum macOS version.
- Studio `.buildkite/shared-pipeline-vars` and `fastlane/Fastfile`: pinned Mac image, CI toolkit, S3 match, notarization.
- Cortext `apps/desktop/fastlane/Fastfile`: certificate-only Developer ID use without provisioning profiles.
- buildkite-ci `src/buildkite/pipelines/studio.tf` and `_pipeline_upload_steps.tftpl.yml`: pipeline registration, team access, and standard upload entrypoint.

## User Decisions

- Full feature workflow requested.
- Signed builds only on version tags.
- Scope above confirmed; Buildkite ZIP artifacts are the distribution destination.
- Keep SwiftPM and use minimal fastlane for signing and notarization.
