#!/bin/bash
# Never trace commands that handle credentials, even when invoked with bash -x.
set +x
set -euo pipefail
cd "$(dirname "$0")/../.."

if [[ ! ${BUILDKITE_TAG:-} =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'Release requires a vMAJOR.MINOR.PATCH tag.' >&2
  exit 1
fi

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Sources/StatsAgentApp/Info.plist)
if [[ ${BUILDKITE_TAG#v} != "$version" ]]; then
  echo 'Release tag must match CFBundleShortVersionString in Sources/StatsAgentApp/Info.plist.' >&2
  exit 1
fi

if [[ -e wp_com_credentials.json || -L wp_com_credentials.json ]]; then
  echo 'Refusing to overwrite existing wp_com_credentials.json.' >&2
  exit 1
fi

echo '--- :rubygems: Install release dependencies'
install_gems

echo '--- :apple: Build, sign, and notarize'
# The helper owns the credentials file for the subprocess lifetime and removes it on exit.
ruby .buildkite/commands/write-credentials.rb bundle exec fastlane release

echo '--- :package: Upload verified app'
buildkite-agent artifact upload ".build/artifacts/Stats-agent-${version}-arm64.zip"
