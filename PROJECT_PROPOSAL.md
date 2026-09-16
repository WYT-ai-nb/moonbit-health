# Project Proposal: MoonBit Maintainer Compass

## Goal

MoonBit Maintainer Compass is a deterministic tool for preparing a MoonBit open-source project for maintainer handoff. It checks the project snapshot, collaboration documents, reproducible commands, Git status, and recent commit risks, then produces a prioritized plan for the next maintainer.

## Problem

An open-source project may build correctly and still be difficult to continue. New maintainers need to know which documents to read, which commands to run, whether the branch is synchronized, and which tasks must be completed before release. These signals are often scattered across a repository.

## September Scope

- Model project files, findings, Git audits, handoff tasks, and release gates in MoonBit.
- Scan real project directories with deterministic traversal and generated-directory exclusions.
- Load line-oriented policy files and write JSON, Markdown, and text reports.
- Expose a command-line interface with profile, baseline, ignore, output, and failure-gate options.
- Read real branch, upstream, remote, and tag metadata from `.git`.
- Persist and report readiness trends across repeated audits.
- Implement deterministic rules for metadata, README, license, tests, examples, contributor guidance, changelog, and CI.
- Add a normalized project inventory, baseline report diff, and readiness trend.
- Evaluate configurable community, release, and strict policies with severity overrides and ignored paths.
- Rank remediation actions by expected score gain and estimated effort.
- Produce text, JSON, Markdown, Git audit, and pass/review/block release-gate output.
- Include healthy and incomplete fixtures plus 92 unit tests.

## Boundary

This project does not publish packages, build a dependency index, or replace a package manager. Its distinct output is a human-oriented continuation plan for a maintainer. Package checking and package publishing are outside the current scope.

## Acceptance Criteria

- `moon test` passes all tests.
- `moon run cmd/main` scans the current repository, loads `moonbit-health.conf`, and prints or writes a complete audit.
- The README explains the rules and usage.
- The repository includes a license, contributor guide, changelog, CI workflow, and proposal.
- The project contains more than 1000 effective MoonBit source lines.

## Future Work

The next iteration will add a Git process adapter for worktree and commit history checks, Mooncakes publishing validation, GitHub pull-request annotations, and a versioned report schema.
