# Project Proposal: MoonBit Maintainer Compass

## Goal

MoonBit Maintainer Compass is a deterministic tool for preparing a MoonBit open-source project for maintainer handoff. It checks the project snapshot, collaboration documents, reproducible commands, Git status, and recent commit risks, then produces a prioritized plan for the next maintainer.

## Problem

An open-source project may build correctly and still be difficult to continue. New maintainers need to know which documents to read, which commands to run, whether the branch is synchronized, and which tasks must be completed before release. These signals are often scattered across a repository.

## September Scope

- Model project files, findings, Git audits, handoff tasks, and release gates in MoonBit.
- Implement deterministic rules for metadata, README, license, tests, examples, contributor guidance, changelog, and CI.
- Produce text, JSON, Markdown, Git audit, and pass/review/block release-gate output.
- Include healthy and incomplete fixtures plus 43 unit tests.

## Boundary

This project does not publish packages, build a dependency index, or replace a package manager. Its distinct output is a human-oriented continuation plan for a maintainer. Package checking and package publishing are outside the current scope.

## Acceptance Criteria

- `moon test` passes all tests.
- `moon run cmd/main` prints a health report, handoff plan, Git audit, and release gate.
- The README explains the rules and usage.
- The repository includes a license, contributor guide, changelog, CI workflow, and proposal.
- The project contains more than 1000 effective MoonBit source lines.

## Future Work

The next iteration will add real file-system scanning, command-line arguments, configurable rules, GitHub Action annotations, and pull-request review mode.
