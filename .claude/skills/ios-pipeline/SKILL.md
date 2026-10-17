---
name: ios-pipeline
description: Run the RehabPath iOS agent team end to end — build a feature, test it, then review it in parallel for UX, data governance and App Store compliance, looping until clean. Use when asked to add or change something in the iOS app, or for a "release audit" before TestFlight/App Store.
---

# RehabPath iOS pipeline

Orchestrate the agents in `.claude/agents/` for work under `ios/`. Pass each agent the full context it needs, because agents start cold: the feature request, the files involved, and the previous stage's report.

## Modes

- **Feature** (default): `$ARGUMENTS` describes a change to make.
- **Release audit**: `$ARGUMENTS` contains "release audit" or "audit". Skip stages 1–2 and run stage 3 against the whole app.

## Stages

```
1 ios-builder ──► 2 ios-test-engineer ──► 3 ┬─ ux-design-reviewer      ─┐
                                            ├─ data-governance-officer ─┼─► 4 fix loop ─► 5 report
                                            └─ apple-review-auditor    ─┘
```

1. **Build:** spawn `ios-builder` with the request. It must run the compliance gate and report files changed and inventory updates.
2. **Test:** spawn `ios-test-engineer` with the builder's report. It adds or updates tests for the change and the must-cover list, and runs what this environment can run.
3. **Review:** spawn the three reviewers **in parallel in one message**, each given the changed-file list and the request. They are read-only.
4. **Fix loop:** collect every Blocker and Major finding. Send them back to `ios-builder` (and to `ios-test-engineer` for missing tests), then re-run only the reviewers that raised them. Stop after 3 rounds; anything still open goes into the report as unresolved. Minor and Nit findings are fixed when they're cheap; otherwise list them.
5. **Verify and report:** run `python3 ios/scripts/compliance_check.py` yourself. If the user wants it pushed, push to the working branch and check the GitHub Actions `iOS` workflow. Code isn't verified until the Xcode build and UI tests are green there.

## Final report to the user

- What changed (files, screens, data fields)
- Test results by layer (compliance gate / core / app / UI), each marked as run or not run, with source
- Review verdicts from each of the three reviewers, plus unresolved findings
- App Store readiness delta (rows whose status changed)
- Next actions, including any ⚖ legal-review items
