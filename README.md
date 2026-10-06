# Stats agent experiment

An experiment with Apple's Foundation Models framework, evaluating whether an on-device agent can answer questions about a WordPress.com site's stats using the WordPress.com stats endpoints.

It holds the experiments, with their questions and latest results, and a macOS app that tries the agent on a site's real data. It needs macOS 26 or later with Apple Intelligence enabled, and Xcode.

## Running the app

1. `cp wp_com_credentials.json-example wp_com_credentials.json`, then replace its values with the WordPress.com OAuth client's ID, a number, and secret.
2. Once, create a code-signing certificate in Keychain Access: Certificate Assistant → Create a Certificate…, with identity type Self Signed Root and certificate type Code Signing. Without it, the keychain asks for the token again after every build.
3. `make run SIGNING_IDENTITY="<the certificate's name>"` builds the app and runs it, with its database in `data/`. `make app`, given the same `SIGNING_IDENTITY` or with it set in your environment, builds `.build/app/release/Stats agent.app`. Choose Always Allow when the keychain asks.
