#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

repository=Automattic/stats-agent-experiment
version=${BUILDKITE_TAG#v}
asset="Stats-agent-${version}-arm64.zip"
artifact=".build/releases/$asset"

# Listing releases distinguishes a missing release from an API or authentication failure.
release_state=$(gh api --paginate "repos/$repository/releases?per_page=100" |
  jq -r --arg tag "$BUILDKITE_TAG" --arg asset "$asset" '
    .[] | select(.tag_name == $tag) |
    if .draft then
      if all(.assets[]; .name == $asset) then "draft" else "unexpected-assets" end
    elif any(.assets[]; .name == $asset and .state == "uploaded" and .size > 0) then "published"
    else "incomplete" end')
case "$release_state" in
  published)
    echo "Release $BUILDKITE_TAG is already published."
    exit 0
    ;;
  incomplete)
    echo "Published release $BUILDKITE_TAG is missing $asset; refusing to modify it." >&2
    exit 1
    ;;
  draft|'') ;;
  unexpected-assets)
    echo "Draft release $BUILDKITE_TAG has unexpected assets; refusing to publish it." >&2
    exit 1
    ;;
  *)
    echo "Multiple releases found for $BUILDKITE_TAG; refusing to modify them." >&2
    exit 1
    ;;
esac

echo '--- :rubygems: Install release dependencies'
install_gems

echo '--- :apple: Build, sign, and notarize'
bundle exec fastlane release

echo '--- :package: Upload verified app'
buildkite-agent artifact upload "$artifact"

echo '--- :github: Upload release'
if [[ -z "$release_state" ]]; then
  gh release create "$BUILDKITE_TAG" --repo "$repository" --verify-tag --draft \
    --title "Stats agent $version" --generate-notes
fi
is_draft=$(gh release view "$BUILDKITE_TAG" --repo "$repository" --json isDraft --jq .isDraft)
if [[ "$is_draft" != true ]]; then
  echo "Release $BUILDKITE_TAG was published during this build; refusing to modify it." >&2
  exit 1
fi
gh release upload "$BUILDKITE_TAG" "$artifact" --repo "$repository" --clobber
echo "Release $BUILDKITE_TAG is ready as a draft. Review it and publish it from GitHub Releases."
