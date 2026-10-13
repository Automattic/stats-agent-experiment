# Stats agent experiment

An experiment with Apple's Foundation Models framework, evaluating whether an on-device agent can answer questions about a WordPress.com site's stats using the WordPress.com stats endpoints.

It holds the experiments, with their questions and latest results, and a macOS app that tries the agent on a site's real data. The app needs an Apple Silicon Mac with macOS 26 or later and Apple Intelligence enabled.

## Downloading the app

Download `Stats-agent-VERSION-arm64.zip` from [GitHub Releases](https://github.com/Automattic/stats-agent-experiment/releases/latest). Unzip it and move **Stats agent.app** to Applications.

## Releasing

Use a dedicated WordPress.com OAuth client restricted to the `statsagent://authorized` redirect; its client secret is embedded in the public download.

1. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in [Info.plist](Sources/StatsAgentApp/Info.plist), then merge to `trunk`.
2. Tag that commit with the matching version and push it: `git tag v0.1.0 <commit>` then `git push origin v0.1.0` (replace the version).
3. Buildkite checks, signs, and notarizes the app, then uploads the ZIP to a draft on [GitHub Releases](https://github.com/Automattic/stats-agent-experiment/releases).
4. Download the draft's ZIP and check that the app opens, logs in, and loads stats. Publish the release from GitHub when it's ready; downloads then become public.

Failed uploads leave a draft that a Buildkite retry can resume. Published releases are immutable; fixes need a new version.

## Running the app

Building requires full Xcode 27, selected with `xcode-select`.

1. `cp wp_com_credentials.json-example wp_com_credentials.json`, then replace its values with the WordPress.com OAuth client's ID, a number, and secret.
2. `make run` builds the app and runs it, with its database in `data/`. It asks you to log in each time it starts.

`make app` builds `.build/app/release/Stats agent.app`, which keeps your login in the keychain.

## Sending feedback

Give Feedback, under each answer, saves your verdict as you go. To send it to us, choose File → Export Data…, check what to include, and send the file it saves.
