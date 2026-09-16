# MoonBit Maintainer Compass

MoonBit Maintainer Compass is a deterministic handoff-plan generator for MoonBit open-source projects. Its focus is not package discovery, dependency management, or package publishing. It answers a maintainer's practical question: what must be prepared before another contributor can continue this repository?

The current revision is an end-to-end MoonBit maintainer-audit tool. It scans a real project directory, produces structured findings, compares reports against a baseline, evaluates configurable policy budgets, ranks remediation work by expected score gain, writes text/JSON/Markdown reports, and generates both a handoff plan and a pass/review/block release gate.

This revision contains more than 3,400 effective non-test MoonBit source lines and 92 passing unit tests.

Rule details are documented in [`docs/RULES.md`](docs/RULES.md). Contributors can use [`CONTRIBUTING.md`](CONTRIBUTING.md) to follow the project workflow.

## Usage

Scan the current repository with its checked-in release policy:

```bash
moon run cmd/main
```

Scan another repository and write a machine-readable report:

```bash
moon run cmd/main -- --root ../another-project --profile release --format json --output report.json
```

Compare a later run with the previous report:

```bash
moon run cmd/main -- --root . --baseline report.json --fail-on-regression
```

Run all rule-engine, scanner, Git-metadata, and CLI tests:

```bash
moon test
```

Example output:

```text
MoonBit Health Report
Score: 100/100
No findings.

Project Inventory
Files: 43
Source files: 15
Test files: 11

Policy Decision
Result: pass
```

## What The Audit Produces

- A deterministic health score and rule findings.
- A normalized project inventory for source, tests, documentation, configuration, automation, fixtures, and generated files.
- A structured diff between a baseline report and the current report.
- A trend model for recording readiness over multiple revisions.
- Configurable severity overrides, ignored paths, and release requirements.
- A policy decision with explicit score, error, warning, and evidence budgets.
- A ranked action queue based on expected score gain and estimated effort.
- Text, Markdown, and JSON output for command-line and automation consumers.
- A real directory scanner with deterministic ordering and automatic generated-directory exclusions.
- Config-file discovery, report output, baseline input, and policy-aware process exit codes.
- Git metadata extraction for branch, upstream, remote, and tag state.
- Persistent readiness trends across repeated audits.

## Configuration

The parser accepts a compact line-oriented configuration:

```text
profile = release
minimum_score = 95
maximum_warnings = 1
require_ci = true
require_changelog = true
ignore = fixtures/generated
rule.MBH007 = off
rule.MBH010 = warning
```

Supported profiles are `community`, `release`, and `strict`. A rule can be set to `off`, `info`, `warning`, or `error`.

Unknown rule IDs and duplicate overrides are rejected rather than silently ignored.

The CLI automatically loads `moonbit-health.conf` from the scanned project root when `--config` is not supplied.

## CLI

```text
moon run cmd/main -- [ROOT] [OPTIONS]

  --root PATH
  --config PATH
  --profile NAME
  --baseline PATH
  --trend PATH
  --format text|json|markdown|all
  --output PATH
  --ignore PATH
  --fail-on-policy
  --fail-on-regression
  --fail-on-gate
  --quiet
  --help
```

## Current Rules

| Rule | Severity | Description |
| --- | --- | --- |
| MBH001 | error | `moon.mod` or `moon.mod.json` exists at the project root |
| MBH002 | error | at least one `moon.pkg` or `moon.pkg.json` package file exists |
| MBH003 | error | `README.md` exists |
| MBH004 | warning | README includes usage or verification commands |
| MBH005 | error | license file exists |
| MBH006 | warning | tests are present |
| MBH007 | info | examples or runnable `cmd/` package exists |
| MBH008 | warning | contributor or maintainer handoff guide exists |
| MBH009 | warning | changelog or history file exists |
| MBH010 | info | GitHub Actions workflow exists |
| MBH011 | warning | README includes both test and demo commands |

## Hackathon Scope

This repository is designed for the MoonBit September Hackathon community ecosystem track.

The September deliverable includes:

- MoonBit data model for project snapshots and findings
- MoonBit rule engine with deterministic scoring
- Project inventory, report diff, and readiness trend models
- Configurable policy profiles and severity overrides
- Ranked remediation queue with expected score gain and effort
- Real directory scanning and cross-platform file I/O
- Command-line arguments, configuration loading, baseline input, and report output
- Text, Markdown, and JSON report formatting
- Maintainer handoff rules distinct from package checking and package publishing
- A handoff-plan output that tells the next maintainer which repository material to prepare
- 92 unit tests covering healthy, incomplete, configured, compared, scanned, Git-metadata, and policy-checked projects
- Example command package
- Public README, license, roadmap, and project proposal

## Boundary With Similar Tools

Tools such as `cakecheck` focus on checking package or project quality. Maintainer Compass has a different output and workflow: it creates a continuation plan for a human maintainer, centered on contributor onboarding, reproducible verification, change history, and CI handoff. It does not publish packages, index dependencies, or replace a package manager.

## Roadmap

- Add Mooncakes publishing checks
- Add JSON schema for machine-readable reports
- Add a Git process adapter for worktree and commit history checks
- Add pull-request regression comments

## Test Fixtures

The `fixtures/` directory contains small healthy and incomplete project examples used to explain rule behavior and guide future file-system scanning work.

## Git Metadata Boundary

The tool reads branch, upstream, remote, and tag information directly from `.git` without executing Git. Working-tree cleanliness, ahead/behind counts, and commit history are marked as unknown because they require a Git process adapter. The release gate treats those unknown fields as `review`, never as a fabricated `pass`.

## License

Apache-2.0
