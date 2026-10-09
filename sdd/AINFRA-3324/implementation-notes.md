# Implementation Notes — AINFRA-3324

## Validation Profile

- Format: `make format` and non-mutating `swift format lint --strict --recursive` over the existing format scope.
- Lint: `make lint` from CLAUDE.md.
- Build: `swift build --build-tests`.
- Tests: `swift test --filter 'CardPickerTests|StatsPeriodsTests|AppDatabaseTests|FeedbackReportTests'`.
- Release checks: shell/Ruby syntax, release guard/cleanup behavior, local fixture app packaging, Buildkite pipeline schema.
- Infrastructure: Terraform formatting and available buildkite-ci policies; no apply.
- Reviewer: built-in independent review.
- QA: no UI changes; browser not applicable.
- Repo skills/subagents: none specific to this repo; buildkite-ci pipeline skill applies to companion registration.

## Baseline

- Formatting, SwiftLint, `swift build --build-tests`, and 30 deterministic tests passed.
- Existing `ExportView.swift` `@Entry` warning observed during compilation.
- No pipeline named `stats-agent-experiment` exists yet in Buildkite.
- Companion checkout: `/tmp/stats-agent-ainfra-3324-buildkite-ci`, branch `ainfra-3324-stats-agent-pipeline`.
- User selected the full feature workflow after initial discovery. The initial lightweight notes were replaced with requirements and spec.

## Iteration 1

### Implementation

- Added the pinned Xcode 27.0/Ruby 3.4.9 toolchain and exact fastlane 2.240.0 dependency, without plugins. Generated `Gemfile.lock` from RubyGems with Bundler 4.0.22, including dependency checksums and Ruby/arm64 Darwin platforms; `bundle lock --local` also succeeds. Network access required sandbox escalation for this read-only dependency resolution.
- Added non-mutating formatting and deterministic-test Make targets plus executable CI wrappers. Packaging accepts optional architecture/signing flags and copies SwiftPM resource bundles into the app before signing; local defaults remain ad hoc.
- Added tag and app-version guards in both the shell release entrypoint and fastlane lane. Shell guards run before `install_gems` or credential preparation. The Ruby credential helper exclusively creates JSON with mode 0600, owns its lifetime around the release subprocess, rejects existing files/symlinks, and removes the file in `ensure`, including handled INT/TERM. This keeps file ownership and cleanup in one process instead of a shell trap with a creation/ownership race.
- Added read-only S3 Developer ID match with no provisioning profiles. The lane selects exactly one valid Automattic Developer ID Application fingerprint from the CI keychain, avoiding dependence on the certificate's company-name spelling and preventing ad hoc fallback.
- Explicitly mapped Automattic's App Store Connect private-key environment variable, notarized/stapled the app, and added codesign/stapler/Gatekeeper verification before creating the final arm64 ZIP. Only the shell's successful final stage uploads the exact artifact path.
- Added Mac queue jobs, finite timeouts, explicit GitHub status contexts, release dependencies, and version-tag-only release conditions. Pinned the CI toolkit to Studio's 6.3.0.
- Documented artifact download, local checks, tag/version rules, exact credential variables, the verified `mobile-secrets/CI/secrets/stats-agent-experiment/env` namespace and SSH key filenames, companion Terraform deployment, and remaining operational validation.
- Implementer checks passed: Ruby syntax for helper/Fastfile, shell syntax for all entrypoints/shared vars, Bundler resolution, and dry-run arm64/hardened-runtime/timestamp packaging commands. Parent owns full task 10 validation and independent review, including release behavior, resource packaging, schema interpolation, and Swift checks. No actual credentials, signing, external publication, commits, or tags were used.

### Validation

- **Linter: PASS.** `make format`, `make format-check`, and the actual CI lint wrapper (including SwiftLint); shell/Ruby syntax checks and `git diff --check` pass. No Swift source or experiment-result changes.
- **Tests: PASS (30/30).** The actual CI build/test wrapper compiled all targets/tests and ran all four deterministic suites successfully.
- **Release scripts: PASS (20 cases).** An isolated fixture harness verified JSON escaping, mode 0600, child exit propagation, invalid/missing credentials, preservation of existing files and symlinks, SIGTERM process-group cleanup, release tag/version guards before dependency access, no upload after lane failure, and upload after cleanup on success. Only fake credentials/stub external commands were used.
- **Packaging: PASS.** Real optimized arm64 `make app` with fixture credentials succeeded. The app includes GRDB's privacy resource bundle; plist and strict/deep ad hoc codesign verification passed before and after a `ditto` ZIP round trip. The credential helper removed its fixture file. This is not evidence of Developer ID signing or notarization.
- **Dependencies/actions: PASS.** Frozen installation of all 103 gems from the committed lockfile succeeded. The real fastlane lane rejected an absent tag and a valid tag with missing OAuth configuration before signing.
- **Pipeline: PASS.** Raw YAML and YAML rendered by `buildkite-agent` 3.128.0 `pipeline upload --dry-run` both pass the official schema. Rendering ran in a container with networking disabled and a dummy token; image/plugin values resolved and the exact tag regex survived interpolation. Nothing was uploaded.
- **Terraform: PASS for available local checks.** The companion registration is formatted. Checkov 3.2.238 source scan passes nine policies; its remaining policy falsely evaluates the Buildkite `filter_condition` string as boolean `True` (reproduced on unchanged Studio). Running that exact policy on the parsed, quote-decoded HCL literal passes. A real Terraform plan and deployment remain infrastructure CI work.
- **Reviewer: PASS, no findings.** Independent review covered changed files, signing action APIs, resources, credentials, documentation, and companion Terraform.
- **QA:** UI/browser testing not applicable. First real signed tag build and downloaded-app login remain rollout checks.

### Local evidence

- `/tmp/stats-agent-ainfra-3324-behavior.py`: disposable behavioral harness (not committed).
- `/tmp/ainfra-3324-validation-lint.log`, `/tmp/ainfra-3324-validation-tests.log`: CI wrapper logs.
- `/tmp/stats-agent-ainfra-3324-app-build.log`: optimized fixture app build.
- `/tmp/stats-agent-ainfra-3324-rendered-pipeline.yml`: actual agent dry-run output.
- `/tmp/stats-agent-ainfra-3324-bundle.log`: frozen dependency installation.
- `/tmp/stats-agent-ainfra-3324-fastlane-no-tag.log`, `/tmp/stats-agent-ainfra-3324-fastlane-no-credentials.log`: real fastlane preflight checks.

### Review handoff

All ten implementation/validation tasks are complete. Prepare draft pull requests for the app and companion infrastructure change after validation; no release tag, Apple signing request, secret provisioning, or Terraform apply is part of this handoff. This follows the companion pipeline skill's reviewed deployment process.

### Remote validation and draft PRs

- App implementation: https://github.com/Automattic/stats-agent-experiment/pull/1
- Pipeline registration: https://github.com/Automattic/buildkite-ci/pull/1011
- Infrastructure CI https://buildkite.com/automattic/buildkite-ci/builds/8063 passed for commit `1bf1da4cd40585b0147024b82b1ed8b05fbea41a`, including the real Terraform/Checkov checks. The generated plan has exactly **3 additions, 0 changes, 0 deletions**: the pipeline and two team bindings.
- The companion checkout was based on upstream trunk before committing, excluding unrelated local reference-checkout commits.
- Deployment is waiting at Buildkite's human confirmation gate, as required by the companion pipeline skill. This supersedes the earlier local-only Terraform validation limitation. The app pipeline's actual signing/notarization/login checks still require provisioning and credentials.

## Final Summary

### Key Decisions

- Retained SwiftPM/Make packaging with minimal pinned fastlane, preserving local ad hoc builds and using Automattic's existing S3 match/notarization conventions.
- Restricted distribution to matching version tags after both CI checks pass. Only the verified, stapled final ZIP can reach artifact upload.
- Kept temporary OAuth credentials under one Ruby process's ownership for exclusive creation, restrictive permissions, and reliable cleanup; selected a unique Developer ID fingerprint from the CI keychain.

### Deviations from Spec

- No scope deviations. Credential lifetime management in Ruby and fingerprint-based identity selection are implementation details supporting the specified safeguards.

### Status

- **10/10 tasks complete; 1 iteration; exit reason: success for local implementation and review.**
- Formatting/lint, compilation, 30 deterministic tests, 20 release behavior cases, fixture app packaging/signatures/resources, frozen gem installation, syntax, and raw/rendered pipeline schema checks passed. Independent review found no issues.
- Terraform formatting and available policy validation passed with the documented Checkov string-coercion workaround. A real Terraform plan, provisioned pipeline, Developer ID signing, notarization, and downloaded-app login remain unverified.

### Evidence

- Local-only [lint log](/tmp/ainfra-3324-validation-lint.log), [build/test log](/tmp/ainfra-3324-validation-tests.log), and [release behavior harness](/tmp/stats-agent-ainfra-3324-behavior.py).
- Local-only [fixture app build](/tmp/stats-agent-ainfra-3324-app-build.log), [rendered pipeline](/tmp/stats-agent-ainfra-3324-rendered-pipeline.yml), and [frozen dependency installation](/tmp/stats-agent-ainfra-3324-bundle.log).
- Local-only real fastlane preflight logs: [absent tag](/tmp/stats-agent-ainfra-3324-fastlane-no-tag.log) and [missing credentials](/tmp/stats-agent-ainfra-3324-fastlane-no-credentials.log). No screenshots/GIFs were needed for this CI-only change.

### Recommended Follow-up

- Hand off draft pull requests for the app and companion Terraform change; review the infrastructure CI plan and deploy through the established Buildkite process.
- Complete pipeline secret, deploy-key, and webhook setup, then run a matching version tag and verify the signed/notarized artifact and login on a downloaded copy. This remains the end-to-end rollout validation.
- No additional implementation TODOs or technical debt were introduced.
