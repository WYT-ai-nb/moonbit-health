# Project Proposal: MoonBit Health

## Goal

MoonBit Health helps MoonBit developers prepare open-source projects for review, reuse, and publication. It checks common project quality signals and produces a readable report that can be used locally or in CI.

## Problem

Many ecosystem packages are hard to evaluate because they miss one or more of the basics: clear usage instructions, tests, license files, examples, or package metadata. Reviewers and contributors need a quick way to see whether a repository is ready for use.

## September Scope

- Implement the core checker in MoonBit
- Model project files, findings, severity, and reports
- Provide built-in rules for metadata, README, license, tests, and examples
- Provide text and JSON report formatting
- Include tests and sample fixtures
- Document usage, rule semantics, and future work

## Acceptance Criteria

- `moon test` runs the rule-engine tests
- `moon run cmd/main` prints a sample health report
- The README explains usage and rules
- The repository uses an OSI-approved license
- The development history can show meaningful MoonBit work during the hackathon period

## Future Work

The next iteration will add a native CLI file-system adapter, Git metadata checks, Mooncakes compatibility checks, and GitHub Actions annotations.
