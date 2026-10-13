#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

echo '--- :rubygems: Install release dependencies'
install_gems

echo '--- :apple: Prepare release draft'
bundle exec fastlane release
