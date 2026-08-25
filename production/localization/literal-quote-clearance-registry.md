# Literal Quote Clearance Registry

**Owner:** Localization / production

**Status:** Active template; no quote is cleared by this document alone

**Date:** 2026-08-13

## Release Gate

A literal quote may enter a player-facing build only when all of the following
are true:

1. its exact wording and source have been verified;
2. the appropriate rights holder or legal basis has been identified;
3. evidence has been reviewed and linked in the entry;
4. territory, platform, language, duration, attribution, and intended media
   scopes cover the actual use;
5. `clearance_status` is `cleared`; and
6. `shipping_status` is `allowed` for that exact scope.

`candidate` never means safe to ship. Unresolved candidates use ordinary
original/localized copy in production.

## Status Vocabulary

| Field | Allowed values | Meaning |
|---|---|---|
| `clearance_status` | `candidate`, `in_review`, `cleared`, `rejected`, `expired` | State of rights verification |
| `shipping_status` | `blocked`, `allowed` | Hard content-build gate |
| `scope` | `in_game_text`, `voice`, `store_listing`, `screenshots`, `trailer`, `notifications`, `merchandise` | Each scope is approved separately |

## Registered Candidates

### `quote.pl.kiler_2.no_i_w_pizdu_01`

| Field | Value |
|---|---|
| Locale | `pl_PL` |
| Exact approved-text candidate | See verbatim block below |
| Declared source | *Kiler-ów 2-óch* |
| Source type | Feature film |
| Source verification | Pending against an authoritative copy/source |
| Speaker/character | Pending verification |
| Author/rightsholder | TBD |
| Rights contact | TBD |
| Intended gameplay use | `polish_export_disaster`, option `a`, resolution reaction |
| Requested scope | `in_game_text` only |
| Platforms/territory/duration | TBD |
| Attribution requirement | TBD |
| Evidence/licence location | None yet |
| `clearance_status` | `candidate` |
| `shipping_status` | **`blocked` until cleared** |
| Store/marketing use | **Blocked**; requires separate explicit scope |
| Notes | Present in the local development/playtest payload at the user's explicit direction. Must be removed or cleared before a public store release; do not voice or use in marketing while blocked. |

This candidate remains scoped to that single early showcase card. The Sponsor
Career Contract deliberately uses original Polish punchlines and does not
duplicate this line, preserving both clearance scope and comedic scarcity.

Verbatim candidate text:

```text
No i w pizdu, i wylądował. I cały misterny plan też w pizdu.
```

### First contextual film-quote wave (local playtest candidates)

All entries below are Polish-only resolution reactions. Their English strings
are separately authored jokes under the same locale keys; they are not literal
translations. The wording/source pairing has been checked against a working
reference, but an authoritative-copy and rights review remain pending. They are
therefore available for local playtesting only and blocked from public release,
voice, screenshots, trailers, store copy, notifications and merchandise.

| Registry id | Declared source | Exact intended use | Status |
|---|---|---|---|
| `quote.pl.psy.nie_chce_mi_sie_gadac_01` | *Psy* | `hater_callout`, option `b`, reaction | `candidate` / **blocked** |
| `quote.pl.dzien_swira.skrajnie_wyczerpany_01` | *Dzień świra* | `burnout_warning`, option `a`, reaction | `candidate` / **blocked** |
| `quote.pl.poranek_kojota.nigdy_nie_czytal_01` | *Poranek kojota* | `masterclass_launch`, option `a`, reaction | `candidate` / **blocked** |
| `quote.pl.kiler_2.lepszy_z_importu_01` | *Kiler-ów 2-óch* | `ai_content_farm`, option `a`, reaction | `candidate` / **blocked** |
| `quote.pl.mis.oczko_sie_odlepilo_01` | *Miś* | `merch_drop_qa`, option `a`, reaction | `candidate` / **blocked** |
| `quote.pl.psy.puszczamy_z_dymem_01` | *Psy* | `final_burnout`, option `accept`, reaction | `candidate` / **blocked** |

Requested scope for every entry is `in_game_text`, Polish locale, local
development/playtest payload only. Author/rightsholder, rights contact,
territory, platforms, duration, attribution requirement and evidence/licence
location remain TBD. No entry is cleared by appearing in this table.

Verbatim candidate texts, keyed in the same order as above:

```text
quote.pl.psy.nie_chce_mi_sie_gadac_01
Nie chce mi się z tobą gadać.

quote.pl.dzien_swira.skrajnie_wyczerpany_01
Jestem skrajnie wyczerpany, a przecież jest rano…

quote.pl.poranek_kojota.nigdy_nie_czytal_01
A czy ty mnie kiedyś widziałeś, żebym ja coś czytał?

quote.pl.kiler_2.lepszy_z_importu_01
Bardzo jak Kiler, bardzo, tylko lepszy, bo z importu!

quote.pl.mis.oczko_sie_odlepilo_01
Oczko mu się odlepiło, temu misiu.

quote.pl.psy.puszczamy_z_dymem_01
Dzisiaj puszczamy z dymem całą naszą pieprzoną przeszłość.
```

## New Entry Template

Copy this section for every proposed literal quote. One entry represents one
exact wording; even a punctuation or wording variant receives a separate entry.

```markdown
### `quote.<language>.<source_slug>.<quote_slug>_<nn>`

| Field | Value |
|---|---|
| Locale | |
| Exact approved-text candidate | See verbatim block below |
| Declared source | |
| Source type | film / television / recording / website / post / other |
| Canonical source URL or physical reference | |
| Source verification | pending / verified; verifier and date |
| Speaker/character or account | |
| Author/rightsholder | |
| Rights contact | |
| Intended gameplay use | Card ID, string key, and context |
| Requested scope | |
| Platforms/territory/duration | |
| Attribution requirement | |
| Evidence/licence location | |
| `clearance_status` | `candidate` |
| `shipping_status` | `blocked` |
| Store/marketing use | blocked unless separately cleared |
| Notes | |

Verbatim candidate text:

```text
PASTE EXACT TEXT HERE
```
```

## Review Checklist

- [ ] Exact wording checked against an authoritative source.
- [ ] Source, author, performer/account, and relevant rights holders recorded.
- [ ] Written permission/licence or reviewed legal basis recorded.
- [ ] Game title, platforms, territory, term, languages, and modification rules
      are covered.
- [ ] In-game text, voice, marketing, and store assets are assessed separately.
- [ ] Required attribution is implemented and tested.
- [ ] Content-rating and store-policy impact is reviewed.
- [ ] Evidence is stored in the approved restricted location, not in a public
      repository when it contains confidential or personal data.
- [ ] Final text in the locale file exactly matches the cleared text.
- [ ] `shipping_status` is changed by an authorized reviewer only.

## Legal Process Note

This registry is a production-control record and **not legal advice**. It does
not itself establish permission, ownership, fair use, quotation rights, parody,
or pastiche. Obtain review appropriate to the jurisdictions and distribution
channels involved.
