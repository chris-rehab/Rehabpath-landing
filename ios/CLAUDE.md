# RehabPath iOS — working rules for Claude and its agents

This directory is the native iOS prototype. Read these before changing anything here:

- `docs/UX_PRINCIPLES.md` — how screens must behave
- `docs/DATA_GOVERNANCE.md` — what data we may hold and how
- `docs/APP_STORE_READINESS.md` — Apple requirements and current status

## Architecture

```
ios/
├── project.yml                    XcodeGen spec (the .xcodeproj is generated, never committed)
├── Packages/RehabPathCore/        Pure Swift domain logic — no SwiftUI/UIKit. Builds on Linux.
│   ├── Models.swift               AppData, Programme, check-ins (every field is in the governance inventory)
│   ├── Consent.swift              Versioned, granular consent
│   ├── AdherenceEngine.swift      Deterministic nudge rules (mirrors dashboard.html's intents)
│   ├── Governance.swift           Retention policy, personal data export
│   └── DataStore.swift            File store (complete protection, no backup) + in-memory store
├── RehabPath/                     SwiftUI app — thin views over AppModel
│   ├── App/                       App entry, AppModel (@Observable), reminders, config
│   ├── DesignSystem/              Card, PrimaryButtonStyle, PainScalePicker, PrototypeNotice
│   └── Features/                  Onboarding, Today, Journey (Progress), CareTeam, Privacy
├── RehabPathTests/                AppModel unit tests (XCTest)
├── RehabPathUITests/              Flow tests + Apple accessibility audits
└── scripts/compliance_check.py    Static App Store + governance gate (runs anywhere)
```

## Conventions

- **Logic goes in `RehabPathCore`** with XCTest coverage. Views stay declarative and call `AppModel`.
- Swift 5 language mode, iOS 17 minimum, `@Observable` + `@Environment(AppModel.self)`.
- System text styles only; `Color.accentColor` / `Color.onAccent` for brand colour; no hex values in Swift.
- Every interactive control gets an `accessibilityIdentifier` (`feature.element`) and a meaningful label.
- Copy follows NZ English and ARCHITECTURE.md §7 content standards (never "proven", "validated", or blaming physios).
- Logging: `os.Logger` with static strings only. Never `print`.
- Tests and previews use `AppData.sample(asOf:calendar:)`. No real patient data, ever.
- Inject the calendar and clock (`AppModel(clock:)`, `AdherenceEngine(calendar:)`) so tests are deterministic.

## Verifying changes

| Check | Command | Where it runs |
|---|---|---|
| Compliance gate | `python3 ios/scripts/compliance_check.py` | Anywhere — **always run** |
| Core tests | `swift test --package-path ios/Packages/RehabPathCore` | macOS or Linux with Swift 5.9+ |
| App + UI tests | `cd ios && xcodegen generate && xcodebuild test -scheme RehabPath -destination 'platform=iOS Simulator,name=<iPhone>'` | macOS + Xcode only |
| All of the above | GitHub Actions `iOS` workflow | Every push touching `ios/` |

Cloud sessions here have no Swift toolchain or Xcode. Push to the branch and read the `iOS` workflow results. Never claim Swift code compiles or tests pass until CI shows it.

## Agent team

The `/ios-pipeline` skill runs the agents in `.claude/agents/`:

`ios-builder` → `ios-test-engineer` → (`ux-design-reviewer` ∥ `data-governance-officer` ∥ `apple-review-auditor`) → fix loop → report

## Known flakiness: Apple's accessibility audit

`performAccessibilityAudit` is not fully deterministic on the iOS 26 simulator. Run 14 failed two
contrast findings (about 9:1 text) on the Privacy tab with code identical to runs 12 and 13, which
passed. CI therefore retries failing UI tests up to 3 times (`-retry-tests-on-failure
-test-iterations 3`): a real defect fails every attempt, a measurement glitch passes on retry.
If an audit finding reproduces on all three attempts, treat it as real. Never skip or weaken the
audit to get green; see the cross-pass contrast rule in `RehabPathUITests.swift`.
