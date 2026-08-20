# King of Cringe — Polish Translator Brief (`pl_PL`)

**Status:** Draft for first localization pass

**Base locale:** `en`

**Target locale:** `pl_PL`

**Date:** 2026-08-13

**Related contract:** `design/quick-specs/bilingual-en-pl_PL-and-literal-quotes-2026-08-13.md`

## Product and Audience

King of Cringe is a satirical idle/tycoon game about building an influencer
career. Its humor comes from the collision between calculated resource growth,
internet drama, sponsorships, public reactions, and the player's questionable
choices. Polish copy should feel written for Polish players, not mechanically
translated from English.

The translation changes presentation only. It must never change rewards,
requirements, option ordering, card weights, timers, progression, or any other
mechanical behavior.

## Voice and Tone

1. **Dry, observant satire.** Report absurd internet outcomes as if they were
   normal business metrics.
2. **Internet-native Polish.** Use natural contemporary phrasing where it fits,
   but avoid slang that already feels obsolete or incomprehensible without a
   niche reference.
3. **Concise punchlines.** Put the strongest word or reveal near the end of a
   sentence. Do not explain the joke after it lands.
4. **Direct player address.** Use natural second-person singular and imperative
   forms when the English source addresses the player directly.
5. **No moral narrator.** Reactions describe consequences; they do not label a
   choice as good, evil, correct, or stupid. The player reads the judgment from
   the situation and resource changes.
6. **Controlled vulgarity.** Profanity is acceptable when it is a deliberate
   punchline or part of a cleared literal quotation. Do not intensify ordinary
   English copy merely to make the Polish version louder.
7. **Correct Polish.** Use Polish diacritics, punctuation, inflection, and
   natural word order. Deliberate errors require an explicit character or joke
   note.

## Initial Text Limits

These are editorial limits for the first pass, based on the portrait card UI.
They are not permission to reduce font size. Any string that exceeds the review
limit must be flagged for a UI fitting check rather than silently shortened.

| Surface | Preferred | Review required above | Notes |
|---|---:|---:|---|
| Card situation/body | 180 characters | 240 characters | Preserve a readable 3–6 line rhythm |
| Card option label | 28 characters | 36 characters | Must remain understandable before a swipe |
| Resolution reaction | 90 characters | 130 characters | One compact payoff beat |
| Action label | 20 characters | 28 characters | Avoid unexplained abbreviations |
| Button/tab label | 16 characters | 22 characters | Prefer established mobile UI terms |
| HUD resource name | 12 characters | 16 characters | Never alter the underlying resource ID |
| Tutorial instruction | 70 characters | 100 characters | One action per instruction |

Automatic line wrapping is allowed. It must not alter the wording of a cleared
literal quote.

## Variables, IDs, and Formatting

- Never translate or edit `card_id`, `option_id`, resource IDs, milestone IDs,
  save keys, localization keys, or format-placeholder names.
- Preserve every placeholder exactly, including braces and case, for example
  `{amount}`, `{resource}`, and `{duration}`.
- Do not add numbers that are not present in the source or supplied as
  placeholders. Tuning may change independently of translation.
- Keep markup balanced and preserve intentional line breaks. Do not insert line
  breaks inside placeholders.
- Option meaning and direction are locked to stable `option_id` values. Never
  infer mechanics from the visible label.
- Missing `pl_PL` copy falls back to `en`; raw localization keys must not be
  player-visible in a release build.

## Game Terminology

Mechanic IDs stay in English even when their visible labels are localized. The
final Polish display terms require writer/game-owner approval and belong in the
project glossary. Until that glossary is approved, translators must not create
competing variants for the following concepts:

| Mechanic ID | English display term | Polish display term | Rule |
|---|---|---|---|
| `Reach` | Reach | **Zasięg** | One term everywhere; inflect naturally in sentences |
| `Cringe` | Cringe | **Cringe** | Do not alternate with embarrassment/shame terms |
| `Haters` | Haters | **Hejterzy** | Inflect naturally; keep the Polish spelling |
| `Morale` | Morale | **Morale** | Preserve its gameplay meaning |
| `Sponsors` | Sponsors | **Sponsorzy** | Distinguish sponsors from money/currency |
| `Burnout` | Burnout | **Wypalenie** | Distinguish state/system from ordinary fatigue |
| `Prestige` | Prestige | **Stałe bonusy / nowa era** | Prefer player-facing outcome over unexplained genre jargon |

## Literal Polish Quotations

Literal quotations are controlled content, not ordinary translation material.

- Insert a quotation only when its entry in
  `production/localization/literal-quote-clearance-registry.md` is marked
  `cleared` for the intended use and territory.
- Copy the approved text exactly. Do not paraphrase, censor, modernize,
  capitalize differently, correct grammar, change punctuation, or append words.
- A cleared quote may be wrapped visually, but its Unicode text must remain the
  approved text (NFC normalization).
- Do not translate a Polish quote into English unless a separately approved
  English text exists. The `en` locale receives its own source copy under the
  same gameplay key.
- Never reuse an in-game clearance in store copy, screenshots, trailers,
  notifications, voice-over, or merchandise unless those scopes are explicitly
  cleared.
- If status is `candidate`, `review`, `blocked`, `rejected`, or unclear, use the
  ordinary localized fallback copy instead.

## Translator Delivery Checklist

- [ ] Meaning and choice intent match the English source.
- [ ] Resource consequences and option order were not inferred or altered.
- [ ] Placeholders and markup match the source exactly.
- [ ] Copy fits the initial text limits or carries a UI-review note.
- [ ] Terminology follows the approved glossary.
- [ ] Tone is satirical and observational, not moralizing.
- [ ] Every literal quote has a `cleared` registry entry for this exact use.
- [ ] Polish diacritics render correctly in the game font.
- [ ] Screenshot/context questions are recorded instead of guessed.

## Legal Process Note

This brief defines the project's content gate; it is **not legal advice**. A
qualified rights professional or lawyer must determine whether a licence,
permission, attribution, or another legal basis is sufficient for each quoted
work and each planned use.
