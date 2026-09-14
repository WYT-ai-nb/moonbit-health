# MoonBit Maintainer Compass

MoonBit Maintainer Compass is a deterministic handoff-plan generator for MoonBit open-source projects. Its focus is not package discovery, dependency management, or package publishing. It answers a maintainer's practical question: what must be prepared before another contributor can continue this repository?

The first version is a pure MoonBit rule engine. It analyzes an in-memory project snapshot, returns structured findings, and produces a prioritized handoff plan in addition to text and JSON reports. The rules cover contributor guidance, reproducible commands, tests, change history, license, and CI. Because the engine is pure, it can later be used by a CLI, an editor extension, or a GitHub Action without changing the rules.

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
| MBH008 | warning | contributor or maintainer handoff guide exists |
| MBH009 | warning | changelog or history file exists |
| MBH010 | info | GitHub Actions workflow exists |
| MBH011 | warning | README includes both test and demo commands |

## Hackathon Scope

This repository is designed for the MoonBit September Hackathon community ecosystem track.

The September deliverable includes:

- MoonBit data model for project snapshots and findings
- MoonBit rule engine with deterministic scoring
- Text and JSON report formatting
- Maintainer handoff rules distinct from package checking and package publishing
- A handoff-plan output that tells the next maintainer which repository material to prepare
- Unit tests covering healthy and incomplete projects
- Example command package
- Public README, license, roadmap, and project proposal

## Boundary With Similar Tools

Tools such as `cakecheck` focus on checking package or project quality. Maintainer Compass has a different output and workflow: it creates a continuation plan for a human maintainer, centered on contributor onboarding, reproducible verification, change history, and CI handoff. It does not publish packages, index dependencies, or replace a package manager.

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
