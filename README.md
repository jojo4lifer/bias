# Project BIAS (working title)

An iPhone app + widget that puts a different K-pop idol quote on your Home Screen every day,
with the source attached. Built for fans; sold cheap.

> Unofficial fan project. Not affiliated with or endorsed by any artist, group, or agency.

---

## Why this can work

The widget *is* the product. A daily quote is a 2-second habit with zero app-opening friction,
and it is naturally screenshot-able — which is exactly the currency of Xiaohongshu.

The moat is not the quotes (anyone can copy text). The moat is:

1. **Curation** — quotes that are actually real, actually sourced, actually good.
2. **Aesthetics** — the widget has to look like something a fan wants on their lock screen.
3. **Fandom specificity** — a fan picks *their* group and sees a line from *that* idol.

The differentiator nobody else does: **every fan of the same group sees the same quote on the
same day.** That turns a private widget into a shared daily ritual, and a daily post on XHS.

---

## Locked decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Widget content | **Text + procedural designed background.** No idol photos. No album art. No agency logos. |
| 2 | Launch market | **Global**, English + Simplified Chinese at launch (Traditional Chinese as fast follow) |
| 3 | Personalization | **Pick your group(s) / bias → quotes filtered to them** |
| 4 | Content source | **Hand-curated, 300–500 quotes, every one sourced** |
| 5 | Pricing | **¥9.90 / month** and **¥68 lifetime** |
| 6 | Process | Spec + launch plan first, then build |

### Why no photos (decision 1, expanded)

Idol photos are agency-owned and idol likeness is protected. Apple rejects this class of app under
**Guideline 5.2.1** (protected third-party material) absent licensing, and K-pop agencies issue
takedowns. A text-only design is not a compromise — it is what makes this shippable in weeks
instead of never. The "aesthetic" comes from typography and generated gradients, not stock imagery.

---

## Documents

| File | What's in it |
|---|---|
| [`docs/product-spec.md`](docs/product-spec.md) | Users, core loop, screens, widget spec, free vs Pro, v1 scope |
| [`docs/tech-spec.md`](docs/tech-spec.md) | Stack, data model, daily-rotation algorithm, WidgetKit plan, StoreKit, file tree |
| [`docs/content-and-legal.md`](docs/content-and-legal.md) | Quote standards, sourcing rules, attribution format, translation policy, legal checklist |
| [`docs/launch-plan.md`](docs/launch-plan.md) | Pricing economics, ASO, screenshots, Xiaohongshu playbook, week-by-week timeline |

---

## Status

- [x] Concept + decisions locked
- [x] Spec written
- [x] **`BiasCore` implemented and verified — 34 checks passing** (`./scripts/check.sh`)
- [x] Content pipeline: `groups.csv` + `quotes.csv` → `quotes.json`, with a linter that refuses bad content
- [x] Widget extension (all four families) + Today screen — written, syntax-checked, **not yet compiled**
- [x] `project.yml` (XcodeGen) + `.github/workflows/ci.yml`
- [ ] First CI run — needs the repo pushed to GitHub
- [ ] Onboarding, archive, share cards, paywall
- [ ] Content curation (the long pole — you can start now)
- [ ] Apple Developer Program enrolment
- [ ] TestFlight → App Store

### What runs today

```
./scripts/check.sh
```

Compiles `BiasCore` + `quotelint` with `swiftc` and runs 34 checks covering the daily rotation,
CSV parsing, the importer, length budgets, localisation fallback, theme contrast, and the content
rules. No Xcode required.

```
.localbuild/quotelint build          # data/*.csv  ->  data/quotes.json
.localbuild/quotelint build --mode development --min 1     # while curating
.localbuild/quotelint --stats        # per-group counts against the 60-quote gate
```

Start curating by editing `data/quotes.csv`. See `data/README.md` for the column reference.

## Getting CI running (needed to compile anything)

There is a local git repo with two commits but **no remote yet**. The Xcode project cannot be built
on this machine, so the first CI run is the first time the app will ever be compiled.

```bash
# 1. create an empty public repo on GitHub, then:
git remote add origin git@github.com:<you>/<repo>.git
git branch -M main
git push -u origin main

# 2. watch it: GitHub -> Actions -> CI
```

Expected first-run outcomes, so nothing surprises you:

- `project.yml` may need a fix (it has never been through `xcodegen generate`).
- The SwiftUI/widget code may need type fixes — only syntax was checked locally.
- Everything in `BiasCore` and the content pipeline should pass first time.

## Repo layout

| Path | What |
|---|---|
| `Sources/BiasCore/` | Foundation-only engine: rotation, models, themes, validation. Locally testable. |
| `Sources/QuoteLint/` | The `quotelint` CLI |
| `BiasApp/` | SwiftUI app |
| `BiasWidgets/` | WidgetKit extension |
| `Shared/` | SwiftUI code compiled into both app and widget |
| `data/` | `groups.csv`, `quotes.csv` (source of truth) and generated `quotes.json` |
| `docs/` | Product spec, tech spec, content/legal guide, launch plan |
| `project.yml` | XcodeGen manifest — the project's source of truth |
| `scripts/check.sh` | Everything that can be verified without Xcode |

## ⚠️ Blocker found: this Mac cannot build the app

Audited the machine: **macOS 12.7.6 on a MacBook Air (Early 2015), Intel, 8 GB, no Xcode installed.**
That model cannot be upgraded past Monterey, and Monterey caps Xcode at 14.2 (iOS 16.2 SDK). App
Store submissions now require a current Xcode/iOS 18 SDK, and the spec targets iOS 17. This is not a
software problem — the hardware is the ceiling.

Options, in order of developer velocity:

1. **Any Apple Silicon Mac** (cheapest new: Mac mini M4). Everything else is a workaround.
2. **Cloud Mac** — GitHub Actions `macos-15` runner + a project generated from YAML (XcodeGen/Tuist)
   so no Xcode is needed to author the project, then build and upload to TestFlight from CI.
3. Borrow a Mac for build/release days only.

See `docs/tech-spec.md §1` — the deployment target may need to drop to iOS 16 if option 2 or 3 is
chosen temporarily.

## Open questions for the owner

1. **Which build machine?** (see blocker above)
2. Do you have a **paid Apple Developer account** ($99/yr)?
2. **App name** — see candidates in `docs/launch-plan.md#naming`. Must not contain a group trademark.
3. ¥9.90 may not be an exact App Store price point; we will map to the nearest one (likely ¥10) and
   read the real price from StoreKit at runtime.
4. Can you commit to **~1 hour/day for 2–3 weeks of curation**? That is the actual critical path.
5. Do you want a **free trial** on the monthly plan (7 days), or straight paid?
