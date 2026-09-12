# MoonBit Health

MoonBit Health is a small quality gate for MoonBit open-source projects. It checks whether a project is easy for maintainers, reviewers, and AI coding agents to build, test, inspect, and publish.

The first hackathon version focuses on a deterministic rule engine written in MoonBit. It analyzes a project snapshot, returns structured findings, and formats both text and JSON reports. The next milestone is a native CLI adapter that reads the real file system and Git metadata.

Rule details are documented in [`docs/RULES.md`](docs/RULES.md). Contributors can use [`CONTRIBUTING.md`](CONTRIBUTING.md) to follow the project workflow.

## Usage

Run the demo report:

```bash
moon run cmd/main
```

Run the rule-engine tests:

```bash
moon test
```

Expected demo output:

```text
MoonBit Health Report
Score: 100/100
No findings.
```

## Current Rules

| Rule | Severity | Description |
| --- | --- | --- |
| MBH001 | error | `moon.mod.json` exists at the project root |
| MBH002 | error | at least one `moon.pkg.json` package file exists |
| MBH003 | error | `README.md` exists |
| MBH004 | warning | README includes usage or verification commands |
| MBH005 | error | license file exists |
| MBH006 | warning | tests are present |
| MBH007 | info | examples or runnable `cmd/` package exists |

## Hackathon Scope

This repository is designed for the MoonBit September Hackathon community ecosystem track.

The September deliverable includes:

- MoonBit data model for project snapshots and findings
- MoonBit rule engine with deterministic scoring
- Text and JSON report formatting
- Unit tests covering healthy and incomplete projects
- Example command package
- Public README, license, roadmap, and project proposal

## Roadmap

- Read actual project directories with a native file-system adapter
- Add GitHub Actions output
- Add Mooncakes publishing checks
- Add custom rule configuration
- Add JSON schema for machine-readable reports

## Test Fixtures

The `fixtures/` directory contains small healthy and incomplete project examples used to explain rule behavior and guide future file-system scanning work.

## License

Apache-2.0
