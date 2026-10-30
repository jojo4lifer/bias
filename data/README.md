# Content data

## Files

| File | Purpose |
|---|---|
| `quotes.template.json` | Empty skeleton. Copy to `quotes.json` to start. |
| `quotes.sample.json` | Three fictional placeholder quotes. **Fails `quotelint` in shipping mode on purpose.** |
| `quotes.json` | The real database. Not committed until it contains real, verified quotes. |

## Adding a quote

1. Copy the object shape from `quotes.sample.json`.
2. `id` — `<group>-<member>-<0001>`, assigned once, never reused, never renumbered.
3. `text` — English ≤ 220 chars, Chinese ≤ 110 chars.
4. `shortText` — **required** if the quote is longer than 60 English / 30 Chinese characters,
   because it is what the lock-screen widget renders.
5. `source` — real title, real `yyyy-MM-dd`, real URL. No URL means no quote.
6. `verified: true` — only after a second person clicked the link and confirmed the wording.
7. Run `swift run quotelint data/quotes.json --mode development` until it is clean.

## The gate

`swift run quotelint data/quotes.json --stats` shows per-group counts. A group ships at **60**
active quotes; flagship groups at **200**. Under 60, fans see repeats inside two months and the
reviews say so.

## Removing a quote

Set `"retired": true`. Never delete. Deleting rewrites history in the diff and loses the audit trail
that proves where the quote came from.

## Why shortText matters

The lock-screen widget has roughly one line. A quote without `shortText` simply cannot appear there.
`quotelint` treats a missing `shortText` on a long quote as an error, not a warning.
