#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

swift build --build-tests
make test-deterministic
