# Stats agent experiment

An experiment with Apple's Foundation Models framework, evaluating whether an on-device agent can answer questions about a WordPress.com site's stats using the WordPress.com stats endpoints.

It holds the experiments, with their questions and latest results, and a macOS app that tries the agent on a site's real data. The app needs an Apple Silicon Mac with macOS 26 or later and Apple Intelligence enabled.

## Downloading the app

Download `Stats-agent-VERSION-arm64.zip` from [GitHub Releases](https://github.com/Automattic/stats-agent-experiment/releases/latest). Unzip it and move **Stats agent.app** to Applications.

## Releasing

Use a dedicated WordPress.com OAuth client restricted to the `statsagent://authorized` redirect; its client secret is embedded in the public download.

1. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in [Info.plist](Sources/StatsAgentApp/Info.plist), then merge to `trunk`.
2. Run `bundle install` if needed, and make sure `BUILDKITE_API_TOKEN` is set in your environment with `write_builds` access to the pipeline. Then run `bundle exec fastlane trigger_new_release` to build the latest `trunk`. Append `commit:<sha>` to choose a commit, or `branch:<name>` to test a branch. The command prints the Buildkite link.

   - Alternatively, open the [Buildkite pipeline](https://buildkite.com/automattic/stats-agent-experiment) and click **New Build**. Set **Branch** to `trunk` and **Commit** to `HEAD` (or choose a different branch or commit). Under **Options → Environment Variables**, enter `PIPELINE=release.yml`, then click **Create Build**. This requires no local Fastlane setup or API token.

3. Buildkite checks, signs, and notarizes the app, then uploads the ZIP to a draft on [GitHub Releases](https://github.com/Automattic/stats-agent-experiment/releases).
4. Download the draft's ZIP and check that the app opens, logs in, and loads stats. Publish the release from GitHub when it's ready; this creates the version tag at the built commit and makes downloads public.

Retry failed builds in Buildkite. If a fix needs a new commit, start another release build with the same app version; it replaces the draft's ZIP and updates its target commit and release notes. Published releases are immutable; fixes need a new version.

## Running the app

Building from source requires Xcode 27.

1. `cp wp_com_credentials.json-example wp_com_credentials.json`, then replace its values with the WordPress.com OAuth client's ID, a number, and secret.
2. `make run` builds the app and runs it, with its database in `data/`. It asks you to log in each time it starts.

`make app` builds `.build/app/release/Stats agent.app`, which keeps your login in the keychain.

## Sending feedback

Give Feedback, under each answer, saves your verdict as you go. To send it to us, choose File → Export Data…, check what to include, and send the file it saves.
