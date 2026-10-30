# Content & Legal

Content is the critical path. Code is ~2 weeks; 400 sourced, verified, translated quotes is 3+ weeks
of real work. Start curation **before** the app is finished.

## 1. What makes a quote shippable

A quote ships only if **all five** are true:

1. **Real.** Verifiable from a public source. No paraphrasings, no "she once said", no
   motivational-quote-site recycling.
2. **Short.** ≤ 220 characters English / ≤ 110 characters Chinese. If it needs setup to make sense,
   cut it.
3. **Self-contained.** Reads as a complete thought out of context. A quote that only works if you
   watched the Vlive is not a widget quote.
4. **Attributed.** Member + group + source + date.
5. **Emotionally useful.** It should make a fan either feel seen, laugh, or send it to a friend.
   Comfort, humor, ambition, gratitude. Not news, not promo, not fan-service catchphrases.

**Instant rejects:** anything from a private DM, paid fan-club-only content, anything that is
actually an official statement from an agency, anything political, anything about another artist,
anything unverified on a fan wiki.

## 2. Sourcing rules

Preferred, in order:

| Tier | Source | Notes |
|---|---|---|
| A | Official YouTube / Weverse / artist social posts | Screenshot the timestamp; keep the URL |
| A | Published interviews (magazines, news outlets) | Link the article + date |
| B | Official variety / reality show episodes | Note episode + approximate timestamp |
| B | Concert or fanmeeting footage | Note date + city |
| C | Fan translations of the above | Only if the original is linked, and mark the original language |

Never: fan wikis as the *source* (use them only to *find* the source), quote-aggregator sites,
Pinterest/Weibo reposts with no trail, AI-generated quotes.

## 3. Attribution format (in-app)

```
"<quote>"
— <Member>, <Group>
<Source title>, <Date>
[View source ↗]
```

The source link is part of the product, not a legal checkbox. It is also the thing that makes
Xiaohongshu users trust the account.

## 4. Translation policy

Every quote needs `en` and `zh-Hans`. That means the original may be Korean, English, or Japanese.

1. **Keep the original wording in the source record** (`lang` field). Never lose it — it is your
   proof.
2. Translate for *meaning and tone*, not word-for-word. Idol speech is casual; a stiff translation
   reads as fake and fans notice immediately.
3. **Have a native speaker read every zh-Hans string before it ships.** Machine translation is a
   drafting tool only. A mistranslated quote is the one error that permanently damages credibility
   in fandom.
4. Don't translate slang into slang you're not sure about. Plain and correct beats clever and wrong.
5. `zh-Hant` in v1.1 can be a script conversion pass + spot check, not a re-translation.

**Cost note:** 400 quotes × 2 languages = 800 strings, plus context lines ≈ 1,600 strings. Budget
real time for this. Doing it badly is worse than shipping 150 quotes done well.

## 5. Legal position

### Copyright in the quotes
Short quotations, attributed, with a link to the source, used for commentary/reference, are the
most defensible posture available. It is not a guarantee — there is no bright-line rule — but it is
how quote apps, lyric-reference sites, and fan accounts operate, and it minimises exposure.

Hard rules that keep you in that posture:
- **Never reproduce a whole work.** No full lyrics, no full interview answers, no full speeches.
  Lyrics in particular: do not ship lyrics. Lyric licensing is a separate, harder problem.
- **Always attribute and always link.**
- **Never imply the artist endorses the app.**
- **Take down fast** if asked (see §7).

### Likeness and trademarks
- No photos, no album art, no logos, no lightsticks, no official fonts. (Already a locked decision.)
- Group and member **names** are used referentially — to identify who said the line. That is normal
  and is how every fan app, news site, and review operates.
- **Do not put a group trademark in the app name, subtitle, icon, or App Store keywords.** No
  "BTS Widget", no "for ARMY". This is the single most common cause of both rejections and takedowns.
- **Do not use fandom names** (ARMY, BLINK, ONCE) in the app name or marketing copy. Same reason.

### Required in-app disclaimer
On the credits/legal screen and in the App Store description:

> This is an unofficial fan project. It is not affiliated with, endorsed by, sponsored by, or
> connected to any artist, musical group, record label, or management agency. All quotations remain
> the property of their respective owners and are reproduced briefly, with attribution, for
> commentary and reference. Group and member names are used only to identify the speaker. To request
> removal of any quotation, contact <email> and it will be removed promptly.

### Apple specifics
- **Guideline 5.2.1** (protected third-party material) — the main threat. Mitigated by having zero
  imagery and by the review notes in `tech-spec.md §7`.
- **Guideline 3.1.2** — subscription paywalls need Terms, Privacy, restore, and clear renewal terms.
- **Guideline 4.2** (minimum functionality) — a widget-only app can be rejected as "not enough
  functionality". The archive, favorites, themes, and sharing are what clear this bar. Do not ship a
  shell that only hosts a widget.

## 6. Takedown response plan

Have this ready before launch, not after.

1. A dedicated email address (`legal@` or a Gmail) listed in the app and on the App Store page.
2. A `retired` flag in `quotes.json` so a quote can be pulled in the next build **without**
   disturbing rotation for everyone else.
3. For a fast, no-build removal: ship a remote kill-list. **v1 has no backend**, so the honest
   answer is "24–72 hours, next app update" — state that turnaround internally and don't promise
   better. If volume grows, add a tiny static JSON kill-list fetch (one URL, cached, no user data).
4. A template reply: acknowledge, remove, don't argue, don't admit liability.

## 7. Curation workflow

Use a spreadsheet (or a `quotes.csv` you convert to JSON with a small script).

Columns:

```
id | group_id | member_id | member_en | member_zh | lang
text_en | text_zh | short_en | short_zh
context_en | context_zh
source_title | source_date | source_url
tags | verified | curator | notes
```

Rules for the sheet:
- `id` format: `<group>-<member>-<0001>`, assigned once, never reused.
- `verified` = a second person clicked the link and confirmed the quote exists.
- Run a **duplicate check on `text_en`** — the same quote attributed to two members is a common and
  embarrassing error.
- Keep a `notes` column for "translation uncertain" — those do not ship until resolved.

## 8. Starter group list

Pick **6–8 groups** for launch. Enough to feel real, few enough to hit 60+ quotes each.

Suggested shape (adjust to your own knowledge and to what Xiaohongshu actually talks about):

| Group | Priority | Target quotes |
|---|---|---|
| A flagship 4th-gen group | P0 | 200 |
| A flagship 3rd-gen group | P0 | 200 |
| A soloist with a big CN fandom | P0 | 100 |
| 2 more 4th-gen groups | P1 | 100 each |
| 1–2 rookies trending on XHS | P1 | 60 each |

Do not launch with 20 groups at 15 quotes each. That produces "new quote" that is a repeat within
two weeks, and the one-star review writes itself.

## 9. Editorial voice

Tone for everything the app says in its own voice (onboarding, paywall, empty states):

- Quiet, warm, never cutesy. You are not a brand account doing a "bestie" voice.
- One sentence where possible.
- English and Chinese should feel like the same person wrote them. Write Chinese first if that is
  your stronger language, then translate to English — it usually reads better than the reverse.
