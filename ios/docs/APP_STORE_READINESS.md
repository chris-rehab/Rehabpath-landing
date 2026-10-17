# RehabPath iOS — App Store Readiness

**Status:** Prototype v0.1.0 · October 2026
**Enforced by:** `apple-review-auditor` agent · `compliance_check.py` · CI (`.github/workflows/ios.yml`)

> Apple changes its requirements every year. The `apple-review-auditor` agent must re-check the live sources below on every audit rather than trust this snapshot:
> - App Review Guidelines — https://developer.apple.com/app-store/review/guidelines/
> - Upcoming requirements — https://developer.apple.com/news/upcoming-requirements/
> - Human Interface Guidelines — https://developer.apple.com/design/human-interface-guidelines/
> - Privacy manifest files — https://developer.apple.com/documentation/bundleresources/privacy-manifest-files

Legend: ✅ done in prototype · ⚠️ verify / partially done · ⛔ blocker before submission · — not applicable yet

## Recommended route: TestFlight first

For a supervised NZ pilot, distribute through **TestFlight** rather than the public App Store:

- **Internal testers** (up to 100 App Store Connect users) need no review.
- **External testers** (up to 10,000) need a lighter Beta App Review, and most of the items below still apply.

The App Store comes later, once the gaps in DATA_GOVERNANCE.md §11 are closed.

## 1. Account and entity

| Item | Guideline | Status |
|---|---|---|
| Enrol as an **organisation** (needs a D-U-N-S number), not an individual — healthcare apps handling sensitive data must come from a legal entity | 5.1.1(ix) | ⛔ |
| Seller name matches RehabPath's legal entity | 2.3 | ⛔ |
| Bundle ID `nz.co.rehabpath.app` registered | — | ⛔ |

## 2. Build requirements

| Item | Status |
|---|---|
| Built with the SDK Apple currently requires (Xcode 26 / iOS 26 SDK since April 2026 — confirm on *Upcoming requirements*) | ⚠️ CI uses the newest Xcode on the runner |
| Deployment target iOS 17.0 (needed for `@Observable`, `sensoryFeedback`, accessibility audit) | ✅ |
| 64-bit only (`arm64`), iPhone portrait | ✅ |
| `ITSAppUsesNonExemptEncryption = false` (only Apple's OS encryption is used) | ✅ |
| App icon 1024×1024, opaque, no rounded corners baked in | ✅ placeholder — ⚠️ replace with final brand artwork |
| Launch screen (`UILaunchScreen`) | ✅ |
| No private APIs; no code downloading or executing at runtime | ✅ |

## 3. Privacy (Guideline 5.1)

| Item | Guideline | Status |
|---|---|---|
| `PrivacyInfo.xcprivacy` present; tracking false; required-reason APIs declared | 5.1.1, manifest rules | ✅ (checked by the gate) |
| Privacy policy URL in App Store Connect **and** in the app | 5.1.1(i) | ⛔ page not published yet (`AppConfig.privacyPolicyURL`) |
| Consent before collection; purpose explained | 5.1.1(ii) | ✅ onboarding consent step |
| Data minimisation — only what the feature needs | 5.1.1(iii) | ✅ see the governance inventory |
| App works without optional permissions | 5.1.1(iv) | ✅ reminders and sharing are optional |
| Account deletion in-app | 5.1.1(v) | — no accounts; ✅ delete-all-data exists. ⛔ becomes mandatory when accounts arrive |
| Health data not used for ads or data mining | 5.1.3(i) | ✅ no SDKs, no ads |
| No personal health information stored in iCloud | 5.1.3(ii) | ✅ excluded from backup, no CloudKit |
| **Health research** needs informed consent **and independent ethics approval** | 5.1.3(iii–iv) | ⛔ before the `aggregateResearch` scope does anything. Prototype UI says "nothing is sent yet" |
| Privacy nutrition label: "Data Not Collected" (true while on-device only) | App Store Connect | ⚠️ must change when sync ships |
| No App Tracking Transparency prompt needed (no tracking) | 5.1.2 | ✅ |

## 4. Health and medical (Guideline 1.4.1)

| Item | Status |
|---|---|
| No diagnosis, treatment or programme-change claims | ✅ copy gate blocks "clinically proven", "cure", "guarantee"… |
| Disclaimer: prototype; supports the physio's programme; contact physio / Healthline | ✅ `PrototypeNotice` on onboarding and Privacy |
| High-pain safety path to a real person | ✅ pain ≥ 7 → physio + Healthline call link |
| Methodology disclosed for any health claim; statistics cited | ✅ Lally et al. cited in-app |
| Regulatory status (SaMD) documented if claims ever go beyond wellness/adherence | ⚠️ governance gap G5 |
| Review notes explain: physio-prescribed programme, sample data, no login, on-device only | ⛔ write at submission |

## 5. Design and functionality

| Item | Guideline | Status |
|---|---|---|
| Native SwiftUI, not a repackaged website | 4.2 | ✅ |
| Complete: no placeholder text, broken links or "coming soon" | 2.1 | ⚠️ prototype labels are honest, but reviewers may flag them as incomplete. Use TestFlight |
| HIG: standard navigation, tab bar, Dark Mode, Dynamic Type | 4.0 | ✅ see UX_PRINCIPLES.md |
| Accessibility audit passes on every tab | — | ✅ UI tests (`performAccessibilityAudit`) |
| Accessibility Nutrition Label (VoiceOver, Larger Text, Dark Interface, Sufficient Contrast, Reduced Motion) | App Store Connect | ⚠️ declare once verified on a device |
| Notifications: opt-in, not used for marketing | 4.5.4 | ✅ |

## 6. Metadata

| Item | Status |
|---|---|
| Screenshots (6.9" iPhone at minimum) made **only** from synthetic data (`-ui-testing -seed-onboarded`) | ⛔ |
| Description accurate to the current state; no "proven" or "validated" | ⛔ draft against ARCHITECTURE.md §7 |
| Age rating questionnaire — answer the medical/wellness questions honestly | ⛔ |
| Support URL live (`AppConfig.supportURL`) | ⛔ |
| Category: Medical or Health & Fitness — Health & Fitness recommended while wellness-framed | ⚠️ decide |
| Copyright, contact details | ⛔ |

## 7. Pre-submission command checklist

```bash
python3 ios/scripts/compliance_check.py              # static gate — must be 0 failed
swift test --package-path ios/Packages/RehabPathCore # domain + governance tests
cd ios && xcodegen generate && xcodebuild test \
  -scheme RehabPath -destination 'platform=iOS Simulator,name=iPhone 17'
```

Then run the `/ios-pipeline` skill with "release audit" so all three review agents sign off.
