# Sponsor Career Contract

## 1. Purpose

Turn an early Sponsor reward into a short remembered storyline: the player
chooses a brand, works through campaign fallout, and decides how to close the
deal, then face a later callback after returning to the game. The feature
demonstrates that cards remember choices while introducing the first meaningful
Sponsor sink budget and an optional logic challenge.

## 2. Player Flow

1. Guaranteed onboarding card `brand_deal_choice` starts the contract.
2. Four completed actions fill Campaign Progress.
3. The next card check presents the branch-specific fallout card.
4. Two completed recovery actions fill Recovery Progress.
5. The next card check presents `sponsor_contract_finale`.
6. The contract completes, but a real offline return of at least five minutes
   arms one final callback selected by the remembered finale choice.
7. The risky-finale callback offers the optional Brief Puzzle. Its result adds
   1–3 Sponsors; skipping resolves the card with no penalty.
8. The callback closes once per career; all stable choice ids remain persisted.

## 3. Core Rules

- Follow-ups use `trigger_condition = "never"`; ordinary weighted RNG cannot
  draw them.
- A due contract card precedes onboarding/weighted selection but never replaces
  an already presented or priority Burnout card.
- Only completed live actions advance objectives. Offline time can arm the
  final callback but never resolves a card or grants its reward.
- New Game resets the contract. Prestige does not erase career story memory.
- Presentation and localization never route logic; only card and option ids do.

## 4. State Model

`not_started -> campaign -> fallout_due -> recovery -> finale_due -> completed`

After a qualifying return: `completed -> callback_due -> closed`.

The system stores `opening_choice`, `fallout_choice`, `final_choice`, and the
current action count. Invalid save state falls back to `not_started`.

## 5. Economy

The core arc grants 4–6 Sponsors including the opening card: enough for one
Staff hire or Shield, never both. The one-shot callback can add 1–3 more only
after a return and player interaction. It cannot create an offline power spike.
Exact values live in CardContentDatabase; cadence lives in
`sponsor_contract.json`.

## 6. Presentation

A compact, non-interactive HUD strip appears only during an active contract.
It shows stages 2/4 through 4/4, exact action progress, or “Decision ready —
next card.” Sponsor green identifies the resource domain, not moral valence.

## 7. Localization and Tone

English and Polish share identical mechanics. Polish copy is transcreated with
local internet rhythm and original punchlines. The existing literal quote
candidate remains limited to `polish_export_disaster` and its release gate.

## 8. Acceptance Criteria

- Both opening choices schedule their matching fallout after four actions.
- Fallout resolution schedules the common finale after two actions.
- A return below five minutes leaves the completed contract dormant; a return
  at or above five minutes schedules exactly one branch-specific callback.
- Brief Puzzle is optional, touch-first, undoable, and pays 1–3 Sponsors by
  performance; Skip pays zero and carries no penalty.
- Follow-ups never enter the normal pool and a due card is selected exactly.
- Save/load round-trips stage, progress, and all choices.
- New Game resets; completion cannot restart from a later repeat of the opener.
- HUD is localized, non-interactive, hidden when inactive, and fits 720×1280.
