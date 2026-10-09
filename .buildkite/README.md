# Buildkite and macOS releases

The pipeline checks internal pull requests, trunk, and tags. Format/lint and build/test jobs run on Automattic's `mac` queue with the `xcode-27.0` image and CI toolkit `6.3.0`. Xcode 27 compiles the tests' macOS 27 symbols; the app's deployment target remains macOS 26. Ruby `3.4.9` and fastlane are pinned, with dependencies recorded in `Gemfile.lock`.

The check jobs run `make format-check lint`, `swift build --build-tests`, and `make test-deterministic`. The four deterministic suites are `CardPickerTests`, `StatsPeriodsTests`, `AppDatabaseTests`, and `FeedbackReportTests`. CI does not run the model experiments.

## Release process

1. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in `Sources/StatsAgentApp/Info.plist` as appropriate, and merge the change after checks pass.
2. Create and push a tag in the exact form `vMAJOR.MINOR.PATCH` on the intended release commit. Its version must equal `CFBundleShortVersionString`; for the current version that is `v0.1.0`.
3. Both check jobs must pass before **Signed macOS app** runs. The release command rejects missing, unrelated, or mismatched tags before installing gems or preparing credentials.
4. Download `Stats-agent-VERSION-arm64.zip` from that job's Buildkite **Artifacts** tab. Unzip and move **Stats agent.app** to Applications on an Apple Silicon Mac running macOS 26 or later with Apple Intelligence enabled.

The release lane uses a temporary CI keychain and read-only fastlane match to import the Developer ID Application certificate from `a8c-fastlane-match` in `us-east-2` for team `PZYM8XX95Q`. It skips provisioning profiles. The matching identity's fingerprint is passed to `make app ARCH=arm64` with hardened runtime and secure timestamps enabled; an absent or ambiguous identity fails the job.

Fastlane notarizes and staples the `.app`. `codesign --verify --deep --strict`, `xcrun stapler validate`, and `spctl --assess` must all pass before the final ZIP is created with `ditto`. The shell entrypoint explicitly uploads only `.build/artifacts/Stats-agent-VERSION-arm64.zip` after the lane succeeds. Intermediate app/notarization archives stay in ignored `.build/`. There is no GitHub Release, DMG, Intel app, or automatic updater.

## Credentials

Provision the pipeline's secrets through the existing `mobile-secrets` process in `~/.mobile-secrets/CI/secrets/stats-agent-experiment/env`. Never put values in this repository, pipeline YAML, command-line arguments, or logs. Ordinary checks build without an OAuth file. The release requires:

| Variable | Value |
| --- | --- |
| `WP_COM_CLIENT_ID` | `133791`, the WordPress.com OAuth client ID, encoded as a positive decimal integer |
| `WP_COM_CLIENT_SECRET` | The OAuth secret for client 133791 |
| `MATCH_S3_ACCESS_KEY` | Access key with read access to Automattic's match S3 storage |
| `MATCH_S3_SECRET_ACCESS_KEY` | Corresponding S3 secret access key |
| `MATCH_PASSWORD` | Password used to decrypt the match certificate storage |
| `APP_STORE_CONNECT_API_KEY_KEY_ID` | App Store Connect API key ID authorized to notarize for team `PZYM8XX95Q` |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | That API key's issuer ID |
| `APP_STORE_CONNECT_API_KEY_KEY` | Raw `.p8` private-key content; fastlane accepts actual newlines or literal `\n` escapes. This lane explicitly maps it to `key_content` with Base64 decoding disabled. |

Buildkite supplies `BUILDKITE_TAG`. The CI toolkit provides `install_gems` and selects the pinned Ruby. `setup_ci` supplies the temporary keychain settings; do not configure an ad hoc signing identity or override the keychain.

`write-credentials.rb` validates the OAuth values and exclusively creates `wp_com_credentials.json` with permissions `0600` using Ruby's JSON serializer. It refuses any existing file or symlink and runs the fastlane subprocess while the file exists. An `ensure` block removes the file on success, failure, or handled SIGINT/SIGTERM. A forcibly killed machine cannot run cleanup; use the disposable CI checkout and never archive the workspace. The app intentionally contains the OAuth client so recipients can log in.

## Initial infrastructure setup

The companion change belongs in `buildkite-ci/src/buildkite/pipelines/stats-agent-experiment.tf`. It uses the standard pipeline upload template, everyone/admin team access, internal pull requests/trunk/tags, no fork builds, explicit per-job GitHub statuses, and intermediate branch cancellation excluding trunk.

1. Submit the Terraform change through buildkite-ci's reviewed workflow. Inspect the plan, wait for its CI checks, and use the approved Buildkite deployment step before merging. Do not run an unreviewed Terraform apply.
2. Install `env`, `private_ssh_key`, and `private_ssh_key.pub` in `mobile-secrets/CI/secrets/stats-agent-experiment/` using the established secret publication process. Add the public key as a read-only deploy key in the GitHub repository settings.
3. Configure the GitHub webhook using the pipeline's [GitHub setup instructions](https://buildkite.com/automattic/stats-agent-experiment/settings/setup/github).
4. Land the app's `.buildkite/` configuration. Confirm an internal PR and trunk build report **Format and lint** and **Build and deterministic tests**. Configure these required checks in GitHub if desired.
5. Confirm client 133791's OAuth settings and API credentials are suitable for this bundle, then run the first matching version tag. Check Developer ID signing, hardened runtime, secure timestamp, notarization, stapling, and artifact upload in the job output.
6. Download that artifact on another Apple Silicon Mac. Confirm it passes Gatekeeper, opens, logs in to WordPress.com, and can retrieve site stats. Verify invalid or unrelated tags produce no release artifact.

Provisioning, secret installation, webhook/deploy-key setup, actual Apple signing/notarization, and the downloaded-app login check remain rollout work. Local syntax, guard/cleanup, deterministic tests, and ad hoc packaging checks cannot establish those operational results.
