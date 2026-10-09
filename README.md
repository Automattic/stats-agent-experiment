# Stats agent experiment

An experiment with Apple's Foundation Models framework, evaluating whether an on-device agent can answer questions about a WordPress.com site's stats using the WordPress.com stats endpoints.

It holds the experiments, with their questions and latest results, and a macOS app that tries the agent on a site's real data. The app needs an Apple Silicon Mac with macOS 26 or later and Apple Intelligence enabled.

## Downloading the app

Once the [Buildkite pipeline](https://buildkite.com/automattic/stats-agent-experiment) is provisioned and a version-tag build succeeds, open its **Signed macOS app** job and download `Stats-agent-VERSION-arm64.zip` from **Artifacts**. Unzip it, move **Stats agent.app** to Applications, and open it to log in to WordPress.com. Buildkite access requires your Automattic account.

The release app includes the OAuth client and is signed and notarized; you do not need Xcode or local credentials. Pull request and trunk builds only run checks. See [CI and release setup](.buildkite/README.md) for provisioning and the first release checklist.

## Running the app

To build locally, install full Xcode 27 and select it with `xcode-select`; the Command Line Tools lack the Foundation Models macros. The app still targets macOS 26.

1. `cp wp_com_credentials.json-example wp_com_credentials.json`, then replace its values with the WordPress.com OAuth client's ID, a number, and secret.
2. `make run` builds the app and runs it, with its database in `data/`. It asks you to log in each time it starts.

`make app` builds `.build/app/release/Stats agent.app`, which keeps your login in the keychain.

## Checking changes

Run `make format-check lint`, `swift build --build-tests`, and `make test-deterministic`. The deterministic suites do not call Apple Intelligence or rewrite experiment results. `make format` fixes formatting; `make test` also runs model experiments.

## Sending feedback

Give Feedback, under each answer, saves your verdict as you go. To send it to us, choose File → Export Data…, check what to include, and send the file it saves.
