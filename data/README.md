# Content data

**The CSV is the source of truth. `quotes.json` is generated — never edit it by hand.**

```
data/groups.csv   ─┐
data/quotes.csv   ─┴─▶  quotelint build  ─▶  data/quotes.json  ─▶  app bundle
```

## Working flow

```bash
# 1. edit data/quotes.csv in Numbers / Excel / Google Sheets
# 2. rebuild the JSON
quotelint build

# 3. see how each group is doing against the 60-quote gate
quotelint --stats

# 4. check everything (also runs the core logic tests)
./scripts/check.sh
```

While curating, use the relaxed rules so placeholder rows do not block you:

```bash
quotelint build --mode development --min 1
```

Before a release, drop the flags — `quotelint` then refuses to build if any quote is unverified,
missing Chinese, missing a source URL, or a group is under 60 quotes.

On this machine `swift run` does not work (broken Command Line Tools), so use the binary built by
`./scripts/check.sh`:

```bash
.localbuild/quotelint build
```

## `groups.csv`

| Column | Required | Notes |
|---|---|---|
| `id` | yes | lowercase, no spaces. `bts`, `aespa`. Never change once quotes reference it. |
| `name_en` | yes | |
| `name_zh` | strongly | Simplified Chinese |
| `name_zh_hant` | optional | Traditional Chinese; falls back to `name_zh` |
| `debut` | optional | year |
| `accent` | optional | hex colour used to theme that group's widget |

## `quotes.csv`

| Column | Required | Notes |
|---|---|---|
| `id` | yes | `<group>-<member>-<0001>`. Assigned once, never reused, never renumbered. |
| `group_id` | yes | must exist in `groups.csv` |
| `member_id` | yes | stable slug for the member |
| `member_en` | yes | display name |
| `member_zh` | strongly | |
| `text_en` | yes | ≤ 220 characters |
| `text_zh` | strongly | ≤ 110 characters |
| `short_en` | **if long** | required when `text_en` > 60 chars — this is what the lock screen shows |
| `short_zh` | **if long** | required when `text_zh` > 30 chars |
| `context_en` / `context_zh` | optional | one line of "where this was said" |
| `source_title` | yes | e.g. `Weverse Live`, `Vogue Korea interview` |
| `source_date` | yes | `yyyy-mm-dd` — **format the cell as plain text**, not a date |
| `source_url` | yes | no URL means no quote |
| `lang` | optional | original language: `ko`, `en`, `ja`, `zh`. Default `ko`. |
| `tags` | optional | `comfort; funny; hype` (semicolons or commas) |
| `verified` | yes | `TRUE` only after a second person clicked the link |
| `retired` | optional | `TRUE` to pull a quote without deleting the row |
| `notes` | optional | your own notes; ignored by the build |

`*_zh_hant` columns are supported if present, and are optional in v1.

## Rules the build enforces

- Every quote needs `verified = TRUE` and a `source_url`.
- Every quote needs Chinese text.
- `text_en` ≤ 220 chars, `text_zh` ≤ 110 chars.
- A quote longer than 60 EN / 30 ZH chars **must** have `short_en` / `short_zh`.
- No duplicate ids. No duplicate text within the same group (the same line attributed to two
  members is the classic embarrassing mistake).
- A group needs 60 active quotes to ship.
- Any id starting with `sample-` blocks a shipping build.

## Removing a quote

Set `retired = TRUE`. Do not delete the row — the diff and the sourcing trail are the audit evidence
that the quote was real.

## Why `short_en` matters more than it looks

The lock-screen widget has roughly one line of space. A quote without a short version simply cannot
appear there, which means the Pro feature people care about most goes unused for that quote.
