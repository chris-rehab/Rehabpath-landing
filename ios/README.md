# RehabPath iOS prototype

A native SwiftUI prototype of the RehabPath patient app. Its job is to keep patients doing their physio exercises through the **behaviour gap** — after pain eases, before healing is complete.

> Prototype for testing. On-device only: no account, no backend, no analytics. Not a medical device.

## Screens

| Tab | What it does |
|---|---|
| Onboarding | Name and goal → pain baseline → plain-language consent with granular, privacy-first toggles |
| Today | Adaptive nudge, one-tap exercise checklist, daily pain score (≥ 7 routes to physio/Healthline) |
| Progress | Streak, programme day, 7-day chart, why to keep going (with citation) |
| Care team | Per-person sharing controls (off by default; nothing is transmitted yet) |
| Privacy | Manage consent, download my data (JSON), delete everything |

## Run it

Needs macOS with Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd ios && xcodegen generate && open RehabPath.xcodeproj
```

Launch arguments for demos and screenshots: `-ui-testing -seed-onboarded` (synthetic data, in-memory, no prompts).

## See it without a Mac

Every CI run (`.github/workflows/ios.yml`) publishes two artifacts you can open from the GitHub Actions page on an iPad:

- **screenshots** — every screen in light, dark and large-text, from synthetic sample data.
- **RehabPath-Playground** — a zip containing `RehabPath.swiftpm`. Unzip it in the Files app, open it in the free Swift Playgrounds app and tap Run. It runs the real app on sample data held in memory (nothing is saved; "Delete all my data" on the Privacy tab returns to onboarding). Regenerate it locally with `python3 ios/scripts/make_playground.py`.

## Quality gates

```bash
python3 ios/scripts/compliance_check.py               # App Store + governance static gate
swift test --package-path ios/Packages/RehabPathCore  # domain logic (also runs on Linux)
```

CI (`.github/workflows/ios.yml`) runs the gate, the core tests on Linux, then the app build, unit tests, UI tests and Apple accessibility audits on an iOS Simulator.

## Standards and agents

- [UX design principles](docs/UX_PRINCIPLES.md)
- [Data governance](docs/DATA_GOVERNANCE.md)
- [App Store readiness](docs/APP_STORE_READINESS.md)
- Agents: `.claude/agents/` — `ios-builder`, `ios-test-engineer`, `ux-design-reviewer`, `data-governance-officer`, `apple-review-auditor`
- Orchestration: the `/ios-pipeline` skill (`.claude/skills/ios-pipeline/SKILL.md`)
