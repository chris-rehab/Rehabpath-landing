# RehabPath Landing Site — Architecture

**Version:** 1.0  
**Last updated:** June 2026  
**Maintainer:** Chris Revans (Founder)  
**Repo:** `chris-rehab/Rehabpath-landing`

---

## 1. Purpose of this document

This document describes the architecture and conventions for the RehabPath marketing and content site. It is a significantly simpler system than the app repo — but the same discipline applies: read this before writing or modifying any file.

---

## 2. System overview

The landing site is a static HTML site with no server-side logic. It handles:

- Marketing and positioning for physiotherapy practices and patients
- Thought leadership content (the `thinking/` directory)
- Patient quiz (self-scoring adherence profile)
- Adherence scorecard for physio practices

```
Visitor browser
      │
      ▼
 Vercel CDN
 (static HTML only — no server, no backend)
      │
      └── Formspree (external form handler)
            └── Submissions → chris@rehabpath.co.nz
```

There is no database connection, no authentication, and no patient health data collected on this site. The quiz captures non-clinical self-reported data only (name, email, readiness scores, barriers).

---

## 3. File structure and naming rules

### Critical naming constraint

**The root landing page must always be named `index.html`.** Any other filename (e.g. `rehabpath-landing.html`, `home.html`) causes a 404 on Vercel deployment. This has caused production issues before. Do not rename this file.

### Current structure

```
/ (root)
├── index.html                    ← Main landing page. Must stay index.html.
├── scorecard.html                ← Adherence scorecard for physio practices
├── rehabpath_logo_transparent.png
│
└── thinking/                     ← Thought leadership articles
    ├── index.html                ← Article listing page
    ├── the-behaviour-gap.html
    ├── why-your-patient-stopped.html
    └── acc-data-transparency.html
```

### Internal linking

All internal links use `.html` extensions throughout. Do not use extensionless URLs or relative paths without `.html` — Vercel static serving does not rewrite these automatically.

Example: `<a href="/thinking/the-behaviour-gap.html">` not `<a href="/thinking/the-behaviour-gap">`

---

## 4. Form handling — Formspree

The quiz and contact forms submit to Formspree, endpoint `mbdqkayb`. This is the only external data processor on this site.

- **What is submitted:** name, email, profile archetype, self-reported goal, barriers, importance score, confidence score, timestamp.
- **What is not submitted:** any health data, clinical information, or ACC claim details. The quiz is a self-scoring marketing tool, not a clinical instrument.
- **Destination:** `chris@rehabpath.co.nz`

Do not add any form that submits health or patient data to Formspree. Any such form belongs in the app repo with Supabase as the backend.

---

## 5. Assets

- Logo: `rehabpath_logo_transparent.png` — transparent background PNG. Do not replace without updating all references throughout the site.
- Fonts: DM Sans from Google Fonts (`fonts.googleapis.com`).
- No locally hosted JavaScript frameworks — vanilla JS only.

---

## 6. Design tokens

CSS custom properties are defined in `:root` in each page. The core palette:

| Token | Value | Usage |
|-------|-------|-------|
| `--orange` | `#f5a623` | Primary brand colour (the "Path" in RehabPath) |
| `--orange-dark` | `#d4891a` | Hover states |
| `--bg` | `#0d1117` | Page background |
| `--surface` | `#151d2e` | Card / panel background |
| `--text` | `#f0f4ff` | Primary text |
| `--text-muted` | `#7a8aa8` | Secondary / helper text |

Do not hardcode hex values outside of `:root`. If a new page is added, copy the `:root` block from an existing page.

---

## 7. Content standards

The following standards apply to all copy on this site and are non-negotiable:

**Every statistic must be citable.** If a number appears in copy (completion rates, dropout percentages, days to habit formation), the source must be documented in the content itself or immediately available in the Evidence Synthesis document. Unsourced numbers are not published. This has been enforced retroactively — the "70%/50% dropout" figures were removed from the landing page after audit.

**Do not overstate the product's current state.** The platform is at PoC stage. Copy must not imply a deployed, validated, or clinically approved product unless that is true. Framing such as "we're building" and "working with physiotherapists to test" is accurate. "Proven" and "clinically validated" are not.

**Do not imply physiotherapist responsibility for patient dropout.** Adherence failure is a structural constraint of appointment-based care. Copy must reflect this framing — the platform supports patients, it does not compensate for physio failure.

---

## 8. Deployment

- Hosting: Vercel
- Repo: `chris-rehab/Rehabpath-landing`
- Custom domain: `rehabpath.co.nz` (DNS via Cloudflare)
- Deployment: auto-deploys from `main` branch on push

**Large file uploads:** The GitHub web editor silently truncates HTML files above approximately 1,010 lines. For any file at or approaching this length, use the GitHub "Upload files" drag-and-drop interface instead of the web editor paste method.

---

## 9. Related documents

| Document | Location |
|----------|----------|
| App architecture | `chris-rehab/rehabpath-app/ARCHITECTURE.md` |
| App security framework | `chris-rehab/rehabpath-app/SECURITY.md` |
| Evidence Synthesis | Project files (confidential) |
