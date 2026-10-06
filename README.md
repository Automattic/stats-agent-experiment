# Stats agent experiment

An experiment with Apple's Foundation Models framework, evaluating whether an on-device agent can answer questions about a WordPress.com site's stats using the WordPress.com stats endpoints.

It holds the experiments, with their questions and latest results, and a macOS app that tries the agent on a site's real data. It needs macOS 26 or later with Apple Intelligence enabled, and Xcode.

## Running the app

1. `cp wp_com_credentials.json-example wp_com_credentials.json`, then replace its values with the WordPress.com OAuth client's ID, a number, and secret.
2. `make run` builds the app and runs it, with its database in `data/`. It asks you to log in each time it starts.

`make app` builds `.build/app/release/Stats agent.app`, which keeps your login in the keychain.

## Sending feedback

Give Feedback, under each answer, saves your verdict as you go. To send it to us, choose File → Export Data…, check what to include, and send the file it saves.
