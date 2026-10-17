# RehabPath iOS — Data Governance

**Status:** Prototype standard v1 · October 2026
**Owner:** Privacy Officer, a role the founder holds until it is formally designated
**Enforced by:** `data-governance-officer` agent · `compliance_check.py` · `RehabPathCore` tests

> This is an engineering governance standard, not legal advice. Items marked **⚖ Legal review** need confirmation from a NZ privacy or health lawyer before any real patient uses the app beyond a supervised pilot.

---

## 1. Scope and current state

The iOS prototype is **on-device only**:

- No backend, no account, and no network calls apart from links the patient taps.
- No analytics, crash reporting, advertising or third-party SDKs.
- All patient data lives in one JSON file in the app's Application Support directory.

Data first leaves the device when the app connects to the RehabPath backend (Supabase, AWS Sydney, described in `rehabpath-app`). Before that happens, §10 must be completed.

## 2. Legal and standards framework

| Framework | Why it applies | Key obligations for us |
|---|---|---|
| **Privacy Act 2020 (NZ)** | We hold personal information about NZ residents | 13 IPPs; Privacy Officer (s 201); notifiable breaches (Part 6) |
| **Health Information Privacy Code 2020** | Injury context, pain scores and exercise adherence are health information | Rules 1–13 replace IPPs for this data (see §3) |
| **Health (Retention of Health Information) Regulations 1996** | May apply if we act on behalf of a health provider (the physio) | ⚖ Legal review: is RehabPath a provider or the provider's agent? |
| **Te Mana Raraunga — Māori Data Sovereignty principles** | Data about Māori patients is a taonga | Collective benefit, guardianship (kaitiakitanga) and consultation before any research use |
| **HISO 10029 Health Information Security Framework** | NZ health sector security baseline | Applies to the backend; use it to design §10 |
| **Apple App Review Guidelines 5.1.1–5.1.3** | Distribution through the App Store | Privacy policy, consent, data minimisation, deletion; health data is never used for advertising |
| **Australian Privacy Principles** | Only if the service expands to AU or AU staff access data | ⚖ Legal review before any AU expansion |

## 3. HIPC 2020 rules, as applied to this app

| Rule | Obligation | How the prototype complies |
|---|---|---|
| 1 Purpose | Collect only for a lawful purpose connected to our function | Every field in §4 lists a purpose used by the adherence engine |
| 2 Source | Collect directly from the individual | All data is entered by the patient |
| 3 Transparency | Tell the patient what, why, who and their rights | Onboarding consent screen + Privacy tab + privacy policy link |
| 4 Manner | Lawful, fair, not unreasonably intrusive | Plain language, no dark patterns, optional scopes off by default |
| 5 Security | Reasonable safeguards | §7 controls (file protection, no backup, no logs) |
| 6 Access | Provide on request | In-app JSON export (Privacy tab → Download) |
| 7 Correction | Correct on request | Pain scores are editable for the current day; ⚖ full profile editing is still a gap (see §11) |
| 8 Accuracy | Check before use | Inputs are validated (pain clamped 0–10, unknown exercises ignored) |
| 9 Retention | Keep no longer than necessary | 365-day rolling window for check-ins, applied on launch |
| 10 Use | Use only for the purpose collected | Engine rules are deterministic and documented in `AdherenceEngine.swift` |
| 11 Disclosure | Disclose only as authorised | Nothing is disclosed in the prototype; sharing needs scope + per-person toggle |
| 12 Cross-border | Comparable safeguards offshore | N/A on device; required before AWS Sydney sync (§10) |
| 13 Unique identifiers | Don't assign NHI-like identifiers unnecessarily | No NHI or ACC claim numbers collected |

## 4. Data inventory

**Rule:** no field is added to `RehabPathCore/Models.swift` until it has a row here.

| Field | Class | Purpose | Source | Stored | Retention | Disclosed to | Consent scope |
|---|---|---|---|---|---|---|---|
| `preferredName` | C2 Personal | Greeting | Patient | Device file | Until deleted | Nobody | coreProgramme |
| `recoveryGoal` | C3 Health | Identity-anchor nudges | Patient | Device file | Until deleted | Nobody | coreProgramme |
| `programmeStartDate` | C3 Health | Programme day, streaks | App | Device file | Until deleted | Nobody | coreProgramme |
| `baselinePain` | C3 Health | Habit-reversion detection | Patient | Device file | Until deleted | Nobody | coreProgramme |
| `checkIns[].completedExerciseIDs` | C3 Health | Adherence, streaks | Patient | Device file | 365 days | Nobody* | coreProgramme |
| `checkIns[].painScore` | C3 Health | Safety prompt, habit reversion | Patient | Device file | 365 days | Nobody* | coreProgramme |
| `careTeam[]` (name, role, org, isSharing) | C2 Personal (third party) | Patient-controlled sharing | Sample data | Device file | Until deleted | Nobody* | shareWithCareTeam |
| `consent` (version, grantedAt, scopes) | C1 Internal | Proof of consent | App | Device file | Until deleted | Nobody | — |
| `programme` | C1 Internal | Today's exercises | Bundled sample | Device file | Until deleted | — | — |

\* Sharing and research are UI-only in the prototype. Nothing is transmitted.

**Deliberately not collected** (data minimisation, compared with the web onboarding): phone/WhatsApp number, email, ACC claim number, NHI, date of birth, location, contacts, HealthKit data, free-text notes.

### Classification

| Class | Meaning | Handling |
|---|---|---|
| C0 Public | Marketing content | No restrictions |
| C1 Internal | Config, consent metadata | No secrets in repo |
| C2 Personal | Identifies a person | Encrypted at rest, patient-controlled |
| C3 Health | Health information under HIPC | C2 handling, plus: never logged, never in notifications, never in backups, never in analytics, synthetic data only in tests and screenshots |

## 5. Consent model

- **Granular scopes** (`ConsentScope`): `coreProgramme` (required), `reminders`, `shareWithCareTeam`, `aggregateResearch`.
- **Defaults:** sharing and research are **off**. Reminders are on (device-local) and still go through the iOS permission prompt.
- **Versioned:** `ConsentRecord.currentVersion`. Changing consent wording or data use means bumping the version. Patients on an older version are sent back through the consent flow (`isOnboarded == false`).
- **Withdrawal:** optional scopes can be withdrawn from the Privacy tab. Withdrawing `shareWithCareTeam` switches off every per-person share immediately. Withdrawing core consent means **delete all data**.
- **System truth wins:** if the patient declines notification permission, the `reminders` scope is withdrawn so in-app state matches reality.
- ⚖ Legal review: consent age. Under-16 patients need guardian involvement; the prototype is for adults only.

## 6. Roles

| Role | Responsibility |
|---|---|
| Privacy Officer | Owns this document, handles access/correction requests (respond within **20 working days**), leads breach response |
| Engineering (incl. agents) | Implements the controls in §7; updates the inventory in §4 before any model change |
| `data-governance-officer` agent | Reviews every change touching models, storage, notifications, logging, networking or third-party code |
| Physio (future) | Sees only what the patient shares, under a data processing agreement |

## 7. Engineering controls (non-negotiable)

1. **Encryption at rest.** The data file is written with `.completeFileProtection`, so it is unreadable while the device is locked.
2. **No backups.** The data file is marked `isExcludedFromBackup` and no iCloud or CloudKit storage is used. *Trade-off:* data doesn't move to a new phone. That is acceptable for a prototype; revisit with server sync.
3. **No health data in logs.** Use `os.Logger` with static strings only. `print`, `NSLog`, `dump` and interpolated log values are blocked by `compliance_check.py`.
4. **No health data in notifications.** Notification text is static and generic; health terms are blocked by the gate.
5. **No third-party SDKs** without a data processing agreement, a privacy manifest review, an inventory update and the governance agent's sign-off. Tracking and ads SDKs are banned outright.
6. **Synthetic data only** in tests, previews, UI tests and App Store screenshots (`AppData.sample`). Never copy real patient data into the repo, test fixtures or issue trackers.
7. **No secrets in the repo.** The gate scans for JWTs, AWS keys and private keys.
8. **Validate at the boundary.** Pain is clamped to 0–10; unknown exercise IDs are ignored; newer schema versions are refused instead of overwritten.
9. **Retention runs on launch** (`DataRetentionPolicy.standard`).
10. **Clipboard and screenshots:** don't copy health data to the pasteboard programmatically.

## 8. Retention

| Data | Prototype (device) | Future server (⚖ Legal review) |
|---|---|---|
| Daily check-ins | 365-day rolling window | Align with Health (Retention) Regs if RehabPath is the provider's agent (10 years); otherwise the minimum needed |
| Profile, consent | Until the patient deletes | Duration of programme + defined grace period |
| Export files | Never stored by the app; created on demand for the share sheet | — |

## 9. Breach response

1. Contain: revoke keys, disable the build in App Store Connect or TestFlight if needed.
2. Assess within 72 hours: is serious harm likely? Health data makes it more likely.
3. If yes, **notify the Privacy Commissioner and affected individuals as soon as practicable** (Privacy Act Part 6, via NotifyUs).
4. Record the incident and lessons learned, and update this document.

## 10. Gate before any data leaves the device

All of the following must be done before the app sends anything to a server:

- [ ] Privacy Impact Assessment completed (OPC template) and signed off
- [ ] Data processing agreement with Supabase/AWS; Sydney residency confirmed; IPP12 cross-border assessment
- [ ] Row-level security reviewed for every table; patient-scoped auth (Sign in with Apple, or passkeys)
- [ ] TLS only; certificate pinning considered; no ATS exceptions
- [ ] `PrivacyInfo.xcprivacy` `NSPrivacyCollectedDataTypes` updated (Health, Fitness, Name, User ID — linked, not tracking)
- [ ] App Store Connect privacy "nutrition label" updated to match
- [ ] In-app **account deletion** (App Review 5.1.1(v)) that deletes server data, not just local data
- [ ] Consent version bumped; existing patients re-consent
- [ ] Physio data-sharing agreement template; physios see only shared data
- [ ] Māori data sovereignty consultation before any research or aggregate use
- [ ] Inventory (§4) updated with the server column, processors and retention

## 11. Known gaps and open questions

| # | Gap | Owner | Status |
|---|---|---|---|
| G1 | Privacy policy and support pages not yet published at the URLs in `AppConfig` | Founder | ⛔ Blocks App Store |
| G2 | Profile editing (HIPC rule 7 correction) — currently delete and re-onboard | Engineering | Planned |
| G3 | Provider vs agent status under the Retention Regulations | ⚖ Legal | Open |
| G4 | Minimum age / guardian consent | ⚖ Legal | Open (adults only for now) |
| G5 | Is the behavioural engine software as a medical device? Currently framed as wellness and adherence support only | ⚖ Regulatory | Open — keep claims non-diagnostic |

## 12. Change control

Any PR that touches `Models.swift`, `DataStore.swift`, `Consent.swift`, `Reminders.swift`, `PrivacyInfo.xcprivacy`, `Info.plist`, networking or a new dependency **must**:

1. Update §4 (inventory) and, if relevant, §5 (consent version).
2. Pass `python3 ios/scripts/compliance_check.py`.
3. Get a `data-governance-officer` review with no unresolved **Blocker** findings.
