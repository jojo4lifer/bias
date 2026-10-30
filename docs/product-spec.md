# Product Spec

## 1. Problem

K-pop fans consume a constant stream of idol content, but almost none of it is *kept*. Quotes get
screenshotted, reposted, and forgotten. Meanwhile the fan's phone Home Screen is the most-seen
surface they own and it is usually empty or utilitarian.

**Insight:** a fan does not want *more* content. They want *one good line, today, from someone they
love.* The constraint is the feature.

## 2. Target user

**Primary — "The Stan."** 16–28. Follows 1–4 groups closely. Lives on Xiaohongshu / Weibo / X.
Already customizes their Home Screen (widgets, icons, wallpapers). Will pay ¥68 once for something
that feels made for them. Will not pay ¥9.90/month forever.

**Secondary — "The Casual."** Likes K-pop, likes quotes, not deep in any fandom. Comes for the
aesthetic. Converts rarely. Useful for reach and word of mouth.

**Anti-user:** someone who wants news, schedules, or merch. Out of scope.

## 3. Core loop

```
Onboard (pick groups, pick language, pick a theme)
   → Widget appears on Home Screen
      → New quote every midnight (same quote for all fans of that group)
         → Widget looks good → screenshot → posted to XHS
            → new installs
```

Secondary loop: open app → browse archive → favorite lines → share a card.

## 4. Feature scope — v1

### In

| Feature | Notes |
|---|---|
| Onboarding | 3 steps: language → pick groups (multi-select, searchable) → pick theme. Skippable. |
| Today screen | Full-screen quote card: quote, member, group, date, source line, share button. |
| Daily rotation | One quote per group per calendar day, deterministic, offline, no network. |
| Widgets | `systemSmall`, `systemMedium`, `accessoryRectangular`, `accessoryInline` |
| Archive | Browse all quotes for your groups, filter by group/member, search text. |
| Favorites | Star a quote, appears in a Favorites tab. Pro-only. |
| Share card | Render 3:4 image (XHS ratio) + 9:16 (IG story) with quote, attribution, small app handle. |
| Themes | 10 procedural styles (gradient + type pairing). No image assets. |
| Daily reminder | Optional local notification at a user-set time. Off by default. |
| Paywall | Monthly + Lifetime, StoreKit 2, restore purchases. |
| Settings | Language, groups, theme, notification time, restore, legal/credits. |
| Localization | `en`, `zh-Hans` at launch. `zh-Hant` in v1.1. |

### Out (explicitly, to protect the timeline)

Accounts, cloud sync, comments, community feed, UGC, photo upload, Apple Watch, iPad layout,
Android, merch, news, concert schedules, AI-generated quotes.

## 5. The daily rotation rule

This is the heart of the product and must be exact.

The calendar is cut into **cycles** of N days, where N is the number of active quotes for the group.
Each cycle is a seeded shuffle of the whole pool; day *i* of a cycle takes element *i* of that
shuffle.

- **No repeats inside a cycle.** A fan sees every quote once before any repeats — which is what
  people actually mean by "a new quote every day".
- **A different order every cycle.** Cycles are seeded by `(groupId, cycleIndex)`.
- **Deterministic.** Pure integer arithmetic and a fixed PRNG, so the app and the widget extension
  always agree, forever.
- **Shared.** All fans of a group see the same line on the same day. This is the marketing hook:
  "今天所有喜欢 XX 的人看到的是同一句话".
- **Offline.** No network, no server, no cold-start empty state.

Two accepted trade-offs, both documented in `tech-spec.md §5`: at a cycle boundary the last quote of
one cycle can equal the first of the next with probability `1/N`; and shipping new quotes shifts the
cycle grid, so on an update day a fan on the old version may see a different line than a fan on the
new one.

If a group has fewer than 60 quotes, the deck runs out inside two months. Enforce a **minimum of 60
quotes per group before that group ships**, and 200+ for the launch flagship groups.

## 6. Free vs Pro

The widget must be free. It is the acquisition channel and the thing in every screenshot. Pro sells
*depth*, not access.

| | Free | Pro |
|---|---|---|
| Daily quote widget | ✅ 1 group | ✅ unlimited groups |
| Widget sizes | Small + Medium | All 4, incl. lock screen |
| Follow groups | 1 | Unlimited |
| Archive | Last 7 days | Full archive |
| Favorites | — | ✅ |
| Themes | 2 | All 10 |
| Font / accent customization | — | ✅ |
| Share cards | ✅ (watermarked) | ✅ (watermarked) |

**Deliberate:** the watermark never goes away, even for Pro. It is free distribution. Do not sell
its removal.

## 7. Screens

1. **Onboarding** — 3 pages, no account, no email. Ends with "Add widget" instructions (with a
   short animated hint, because adding a widget is where most users get stuck).
2. **Today** — the hero. Quote card fills ~70% of the screen. Tap to reveal source + context.
   Double-tap to favorite.
3. **Archive** — vertical list of cards, grouped by month. Filter chips: All / by group / Favorites.
4. **Share sheet** — chooses 3:4 or 9:16, theme, then native share sheet.
5. **Settings** — groups, language, theme, reminder, restore, legal.
6. **Paywall** — one screen. Monthly top, Lifetime below with "best value" badge, one-line benefit
   list, restore link, terms + privacy links.

## 8. Widget spec

| Family | Content | Constraint |
|---|---|---|
| `systemSmall` | Quote (truncated to ~90 chars), theme gradient, small app mark | Must be legible at a glance; never show a quote that needs the full sentence to make sense |
| `systemMedium` | Quote (~160 chars) + member name + group + date | Primary marketing surface |
| `accessoryRectangular` | One short line, monochrome-friendly | Quote must be ≤ 60 chars or a dedicated `short` variant is used |
| `accessoryInline` | `Name: quote` truncated | Fallback to member name only if no short quote |

**Design rules**

- Quote is the largest element. Attribution is small, bottom, always present.
- No quote is shown in a widget unless it passes a length check for that family. Store a
  `shortQuote` variant on any quote longer than 60 characters.
- Contrast ratio ≥ 4.5:1 against the theme background. Some themes are light; check both.
- Widgets must never show a placeholder like "Loading…". Content is bundled.

## 9. Success metrics

| Metric | Target (90 days) |
|---|---|
| Install → widget added | ≥ 55% (proxy: widget-add onboarding step completed) |
| Free → Pro conversion | 4–7% |
| Pro mix: lifetime vs monthly | 70/30 expected |
| Paywall view → purchase | 8–12% |
| D30 retention (app open) | ≥ 25% |

Instrumentation is deliberately absent in v1 (no tracking, no ATT prompt, clean privacy label).
Use App Store Connect (impressions, conversion rate, proceeds) plus paywall funnel events added in
v1.1 via a privacy-friendly SDK.

## 10. Non-goals

Do not build a fan social network. Do not build a news app. Do not add AI quote generation — a
fabricated idol quote is the one unrecoverable failure mode for this product.
