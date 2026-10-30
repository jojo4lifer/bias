# Launch Plan

## 1. Naming

Requirements: no group trademark, no fandom name, works in English and Chinese, ≤ 12 characters so it
fits under an icon on a Home Screen.

| Candidate | Why | Risk |
|---|---|---|
| **Bias** | Fandom-native word, one syllable, works as `本命` in Chinese. Strong icon potential (one glyph). | Common word — App Store name availability is a real risk |
| **Bias Daily** | Keeps the fandom word, adds the daily promise | Slightly longer |
| **One Line** | Evokes "one quote a day", elegant, no trademark exposure | Chinese localization is awkward |
| **Quietly** | Aesthetic-first, matches the voice | Loses the fandom signal |
| **本命语录** | Perfect Chinese App Store name | No English equivalent |

**Recommendation:** English name `Bias Daily`, Chinese localized name `本命语录`, subtitle EN
"Daily idol quotes on your Home Screen" / ZH "每天一句，来自你喜欢的人". Verify the exact name is
free in App Store Connect before designing the icon — this is a 5-minute check that saves a week.

Do not put "K-pop" in the name. It narrows you to a category and reads as unofficial merch.

## 2. Pricing and economics

| Product | Price | Net after 15%* |
|---|---|---|
| Monthly | ¥9.90 (nearest App Store point, likely ¥10) | ~¥8.4 |
| Lifetime | ¥68 | ~¥57.8 |

\* Enrol in the **App Store Small Business Program** before launch — 15% instead of 30% for
developers under $1M/year. It is a form, not a negotiation.

### Why both

- **Lifetime at ¥68** is the product. Chinese users distrust 自动续费, and ¥68 is an impulse price for
  something a fan keeps on their Home Screen. Expect ~70% of revenue here.
- **Monthly at ¥9.90** exists to (a) lower the entry barrier for the price-sensitive, (b) make ¥68
  look like a deal (7 months break-even), and (c) catch people who would never pay ¥68 upfront.
- Do **not** add a third product. Two options convert better than three.

### Reality check on scale

| Installs (90 days) | Conversion | Buyers | Revenue (net) |
|---|---|---|---|
| 5,000 | 5% | 250 | ~¥11,000 |
| 20,000 | 6% | 1,200 | ~¥55,000 |
| 100,000 | 6% | 6,000 | ~¥275,000 |

Net revenue assumes 70/30 lifetime/monthly and ~3 months average subscription life. This is a
**good side project and a real small business at 100k+ installs** — it is not a venture-scale
business, and content ops scales linearly with it. Plan accordingly: keep costs near zero, do the
curation yourself, and treat the first 6 months as a distribution experiment, not a revenue target.

### Free trial

Recommended: **7-day free trial on monthly only.** Lifetime has no trial. Watch refund rates in the
first month — a trial that converts badly is worse than no trial.

## 3. App Store optimisation

| Field | English | Chinese (zh-Hans) |
|---|---|---|
| Name (30) | Bias Daily | 本命语录 |
| Subtitle (30) | Daily idol quotes on your Home Screen | 每天一句，来自你喜欢的人 |
| Keywords (100) | kpop,quote,widget,idol,daily,aesthetic,bias,home screen,lock screen,fan | 追星,语录,widget,小组件,桌面,偶像,本命,每日一句,饭圈,壁纸 |

Rules:
- Keywords are comma-separated, **no spaces after commas**, no repeated words already in the name.
- Do not use group or fandom names in keywords. It is a trademark risk and Apple has removed apps
  for it.
- First 3 lines of the description do all the work. Lead with the ritual, not the feature list:

> Every morning, one line from the person you love most — on your Home Screen.
> 每天早上，你喜欢的人对你说一句话。

Screenshot order matters more than anything else in the listing:

1. Medium widget on a real-looking Home Screen — **the hero shot**
2. Lock screen widget
3. The Today screen
4. "Pick your bias" onboarding
5. Archive / favorites
6. Share card → "screenshot and post"

Localize screenshots for `en` and `zh-Hans`. Do not machine-translate text baked into images; redo
the layout in each language.

## 4. Xiaohongshu playbook

XHS is a **content** channel, not an ad channel. Ads there are expensive and poorly targeted for
this. The play is a daily posting habit plus seeding.

### The daily ritual (this is the whole strategy)

Post once a day, same time, same format:

```
Cover: the widget screenshot (3:4, the actual app output)
Title: 「今天的本命语录」+ the group name
Body:  the quote, the source, one line of your own feeling, then
       "App Store 搜：本命语录"
Tags:  #追星 #语录 #桌面布置 #小组件 #kpop #本命
```

Why it works: the post *is* the product demo, it is zero-effort to produce (the app makes the
image), and it compounds — after 30 days you have 30 indexed posts, each a permanent search entry
for "语录" and "桌面". Fans who search a group name find a wall of your screenshots.

**The hook to lean on:** "今天所有喜欢 XX 的人，看到的是同一句话" — the shared daily quote is a
genuinely novel thing to post about, and it invites comments ("我也是这句！"), which is what the
algorithm rewards.

### Cadence and rules

- **1 post/day minimum for 60 days.** Consistency beats quality here; the algorithm rewards accounts
  that post daily.
- Post in the evening, 20:00–23:00 CN time.
- Reply to every comment in the first hour. Comments are the ranking signal.
- **Do not put links in the post** — XHS suppresses them. Say "App Store 搜索：本命语录" in the
  caption and pin a comment with the name.
- Disclose paid partnerships where applicable; undisclosed ads get the account limited.
- Never claim to be official. Never post idol photos you don't own — use your own widget output.

### Seeding

- Identify **20–50 micro-KOC fan accounts** (1k–20k followers) who already post quote/aesthetic content.
- Offer free lifetime codes (App Store Connect promo codes, 100 per version).
- Ask for a post with their own widget screenshot, not a scripted review. Scripted reviews read as ads.
- Do this in **two waves**: 10 accounts before launch (so there is content when you go live), 20 after.

### Other channels
- **X / Twitter** — fandom quote accounts already exist and have big followings. Quote-tweet them
  with your widget screenshot. Low effort, decent reach.
- **Threads / Instagram** — bonus, not a priority for a CN-first audience.
- **Weibo** — high effort, high reward, but a different content style. Phase 2.

## 5. Timeline

Assumes part-time work. The critical path is content, not code.

| Week | Work | Deliverable |
|---|---|---|
| 0 | Curation starts. Name check. Apple Developer account. | `quotes.csv` begun, name reserved |
| 1 | `BiasShared` + Today screen + onboarding shell | App runs with real quotes |
| 2 | Widgets (small/medium) + archive + themes | Widget on device |
| 3 | Paywall + StoreKit + share cards + lock screen | Feature complete |
| 3 (parallel) | Curation continues. **Content gate: ≥60 per group** | 300+ quotes verified |
| 4 | Localization, TestFlight, icon, screenshots, privacy/terms pages | Build in TestFlight |
| 4 | Submit to App Review | Submission |
| 5 | Review buffer (expect 1 rejection, budget for it) | Live |
| 5–13 | Daily XHS posting, KOC seeding, weekly quote top-ups | Growth |

**Budget 1–2 rejections.** Most likely causes: 5.2.1 (third-party material) and 4.2 (minimum
functionality). Both are answered by the review notes in `tech-spec.md §7` and by making sure the
archive/favorites/themes are real, not stubs.

## 6. Launch-day checklist

- [ ] Small Business Program enrolled
- [ ] Products live in App Store Connect, prices correct, localized display names
- [ ] Privacy policy + terms hosted at a stable URL, linked in app **and** on the store page
- [ ] Support email live, tested
- [ ] App Privacy label = Data Not Collected
- [ ] Disclaimer visible on the credits screen and in the description
- [ ] Promo codes generated for KOC seeding
- [ ] Screenshots in `en` and `zh-Hans`
- [ ] TestFlight run: install → widget add → purchase → restore → refund path checked
- [ ] First 14 days of XHS posts drafted ahead of time (do not rely on daily inspiration)

## 7. Post-launch roadmap

| Version | Contents | Why |
|---|---|---|
| 1.1 | `zh-Hant`, 2 more groups, analytics (privacy-friendly) | Reach + measurement |
| 1.2 | Per-widget group selection polish, more themes, "quote of the week" widget | Pro retention |
| 1.3 | Widget tap → deep link to that quote's source | Trust + dwell time |
| 2.0 | Remote content updates (static JSON) so quotes refresh without an app update | Content velocity |
| Later | Community submissions (moderated), annual recap ("your year of quotes") | Retention, virality |

Do not build 2.0's backend until you have evidence that content velocity is the bottleneck. With
400 quotes in 8 groups, it is not, for the first six months.
