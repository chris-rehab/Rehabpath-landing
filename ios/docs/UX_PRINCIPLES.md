# RehabPath iOS — UX Design Principles

**Status:** Prototype standard v1 · October 2026
**Enforced by:** `ux-design-reviewer` agent · UI tests (`performAccessibilityAudit`)

RehabPath exists to close the **behaviour gap**: the period when pain eases but healing isn't finished, and patients stop exercising. Every screen should make the next exercise easier to do, not just easier to record.

These principles are requirements, not suggestions. A change that breaks one needs a written reason in the PR.

---

## 1. Make the next action effortless

Our behaviour model is Fogg's: Behaviour = Motivation × Ability × Prompt. We can't add much motivation, but we can remove friction.

- The **Today** tab is the home screen. Ticking off an exercise takes **one tap**, with no confirmation dialog.
- Logging a full day takes **≤ 6 taps**: 5 exercises plus 1 pain score.
- One prominent action per screen at most (`.buttonStyle(.primary)`).
- Never ask for data the engine doesn't use. Each new input needs a row in the data inventory (DATA_GOVERNANCE.md §4) that says what it's for.

## 2. Celebrate any progress, never shame

- Partial completion counts. "One is better than none" is a real message, not a fallback.
- **Banned:** red "failed" states, "streak lost" messages, guilt copy ("You let yourself down"), countdowns, loss-framed streaks.
- After missed days, say **restart**, not **broken**. The adherence states `slipping` and `atRisk` are internal. Patients never see them as labels or colours.
- Haptic confirmation (`.sensoryFeedback(.success)`) fires when the patient finishes the day, not on every tap.

## 3. Anchor to the patient's own goal

- The recovery goal is captured in the patient's own words during onboarding and reused in nudges ("…a step towards *walking the dog*").
- Use the patient's preferred first name only. We greet with "Kia ora" because RehabPath is built for Aotearoa New Zealand.

## 4. Safety before engagement

- A pain score ≥ 7 overrides every other nudge. The patient is pointed to their physio and Healthline (0800 611 116), with a tappable call link.
- The app **never** diagnoses, changes the prescribed programme, or suggests pushing through pain.
- The disclaimer is always reachable: "Prototype for testing… doesn't diagnose or treat injuries" (`PrototypeNotice`).

## 5. Be honest about what this is

This follows ARCHITECTURE.md §7.

- Label prototype features plainly. Care-team sharing and research consent say "Prototype: nothing is sent yet."
- No "clinically proven", "validated" or "guaranteed" language. `compliance_check.py` blocks these phrases.
- Every statistic shown in the app carries its source (see the Progress tab's Lally et al. citation).

## 6. The patient is in control

- **Private by default.** Care-team sharing and research consent start **off**. Reminders start on because they never leave the device, and iOS still asks for permission.
- Each consent is granular, explained in one sentence, and can be changed later from the Privacy tab.
- Export and delete are two taps from the Privacy tab. Deleting asks for confirmation with a destructive-styled button.
- Ask for system permissions **in context**. The notification prompt only appears after the patient opts into reminders.

## 7. Accessible by default (WCAG 2.2 AA + Apple HIG)

| Requirement | How we meet it |
|---|---|
| Dynamic Type up to AX5 | System text styles only (`.body`, `.headline`…); no fixed font sizes; layouts scroll |
| VoiceOver | Each exercise row reads as one element: "Mini squats, 3 sets of 10, Not done", with a hint; charts carry per-bar labels |
| Contrast ≥ 4.5:1 | Accent `#9A5800` light (5.6:1) / `#F5A623` dark (8.4:1); text on accent `#FFF` / `#0D1117`. Secondary text uses `Color.mutedText` (never `.secondary`, which is ~3.4:1); destructive actions use `Color.destructiveText` (never system red, ~3.5:1) |
| Settings-style screens | Build them as cards in a `ScrollView` (Today, Progress, Privacy), not a long grouped `Form`: after ten CI runs, a long `Form` kept drawing unexplained Dynamic Type / clipping findings from Apple's audit on rows, headers and notes, while the card layout passes |
| Explanatory text in forms | Use a plain text row (see `CareTeamView.intro`, `PrivacyView.note`), not a `Section` footer: Apple's Dynamic Type audit flagged every footer we tried, at any length or wording, while the same text passes as a row |
| Touch targets ≥ 44×44 pt | Rows set `minHeight: 44`; primary buttons are 50 pt |
| Not colour alone | Done state uses a checkmark icon + VoiceOver value, not only colour |
| Reduce Motion | Only system animations, which respect the setting automatically |
| Automated gate | `performAccessibilityAudit()` runs on every tab in UI tests |

## 8. Native, not a web wrapper

- System components only: `NavigationStack`, `TabView`, `Form`, `List`, `Toggle`, SF Symbols, Swift Charts. These pick up iOS styling (including Liquid Glass on iOS 26), Dark Mode and accessibility for free.
- Support **light and dark** appearance. The landing site is dark-only, but the app follows the system setting.
- Portrait iPhone only for the prototype.

## 9. Calm notifications

- At most **one** reminder a day, at a fixed time (6 pm by default).
- Notification text is generic ("A few minutes for today's exercises?"). It never shows health details on the lock screen.
- No badges, no marketing pushes.

## 10. Plain language

- Aim for a reading age of about 12. Use short sentences and the second person ("you"), not clinical jargon.
- Write in NZ English (programme, colour, organisation).
- Errors say what happened and what to do next, and never blame the patient.

---

## Screen acceptance checklist

The `ux-design-reviewer` agent checks every UI change against this list:

- [ ] Primary task reachable in ≤ 1 tap from the Today tab
- [ ] No shame / loss framing; no red failure states
- [ ] Copy is plain language, NZ English, honest about prototype status
- [ ] Every interactive element has an accessibility label (and identifier for tests)
- [ ] Works at the largest accessibility text size without truncating essential info
- [ ] Light and dark appearances both checked
- [ ] Any new data input is justified in the data inventory
- [ ] Safety path (pain ≥ 7) still takes priority
- [ ] UI test covers the new flow; accessibility audit passes
