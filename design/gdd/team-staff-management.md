# Team/Staff Management

> **Status**: Implemented (2026-07-28) — `src/core/staff_system.gd` + `src/ui/staff_panel.gd`
> **Author**: user + agents
> **Last Updated**: 2026-07-28
>
> **Implementation note (2026-07-28)**: shipped as designed, with F1/F2 and the
> locked `ceil()` rule asserted against this document's own worked examples
> (`tests/unit/staff/staff_formulas_test.gd`). All three pull-model getters are
> wired: Sponsor Manager into `DecisionCardSystem`'s card resolution (F3b, next
> to the Class Path sponsor multiplier), Troll and Assistant into
> `OfflineProgressSystem.simulate_offline()` (F3 / Core Rule 6). Era-local reset
> runs from `PrestigeSystem.on_burnout_accepted()` beside
> `ClassPathSystem.reset_era_state()` (Core Rule 2), and counts round-trip
> through `SaveSystem`/`BootController`. UNCHANGED pre-existing gap, exactly as
> this GDD's Core Rule 5 states: the live-play call site for the whole
> `H_rate(C) x META_HATERS_RESIST` pipe still does not exist, so Troll's
> multiplier currently only takes effect offline.
> **Implements Pillar**: Pillar 4 (offline pierwsza klasa — Asystent multiplier bezpośrednio przyspiesza offline progression) primarily; Pillar 3 (satyra przez mechanikę) przez taksonomię ról (trolle/asystenci/sponsor managerowie jako komentarz do ekonomii influencerów); Pillar 2 (decyzje mają pamięć) przez era-lokalny reset jako część stawki Wypalenia.

## Overview

Team/Staff Management to warstwa ekonomii, w której gracz zatrudnia zespół (trolle/asystenci/sponsorzy, `game-concept.md`) za Sponsory, zwiększając tempo generowania zasobów zarówno w żywej grze jak i offline. Interakcja: aktywna decyzja inwestycyjna (którego pracownika zatrudnić), ale efekt działa pasywnie/automatycznie w tle — raz zatrudniony pracownik pracuje ciągle, szczególnie offline. Bez tego systemu Sponsory nie mają żadnego sinka (`resource-system.md` już to flaguje jako otwarty problem), a Pillar 4 (offline pierwsza klasa) nie ma dźwigni do przyspieszenia — gracz nie buduje niczego między sesjami poza czekaniem.

## Player Fantasy

"Przestałem robić wszystko sam — teraz mam LUDZI od tego." Bezpośrednio: moment zatrudnienia to satysfakcjonująca decyzja inwestycyjna, twardą walutą (Sponsorzy) za trwały wzrost tempa. Pośrednio: efekt działa w tle, najsilniej odczuwalny przy powrocie z offline ("mój zespół pracował beze mnie"). Satyrycznie (Pillar 3): trolle/asystenci/sponsorzy to nie neutralne "pracownicy" — to komentarz do prawdziwej ekonomii influencerów (płatne engagement farmy, przepracowani asystenci, kapitał zewnętrzny), nie generyczne fantasy "zatrudniam ludzi" z innych idle gier.

## Detailed Design

### Core Rules

1. **Trzy role, każda inny zasób** (`game-concept.md`'s "trolle/asystenci/sponsorzy"):
   - **Troll** — mnożnik tempa Hejterów (satyrycznie: płatne konta trollujące generują kontrowersję).
   - **Asystent** — ogólny mnożnik tempa OFFLINE (Pillar 4 — dokładnie `game-concept.md` line 67, "zespół jako warstwa zwiększająca tempo offline").
   - **Sponsor Manager** — mnożnik dochodu Sponsorów (rola PR-owa przyciągająca więcej sponsoringu, odrębna od samej waluty Sponsorzy). **Doprecyzowane (economy-designer finding)**: mnożnik stosuje się wyłącznie do KWOTY Sponsorów przyznawanej przez kartę kwalifikującą się (`sponsor_offer_shady`/`brand_deal_choice`), NIGDY do częstotliwości/wagi losowania takich kart w puli — to druga, znacznie groźniejsza pętla sprzężenia zwrotnego (więcej Sponsor Managerów → więcej kart sponsorskich → więcej Sponsor Managerów), której eskalujący koszt sam z siebie by nie ograniczył. Ograniczone wyłącznie do kwoty per karta.
2. **`staff_count[type]: int` jest era-lokalne** — resetuje się do zera przy każdym zaakceptowanym Wypaleniu, tak samo jak Class Path affiliation i wszystko poza META_BONUS (Core Rule 5, `prestige-checkpoint-system.md`). To jest część stawki Wypalenia, nie wyjątek od niej.
3. **Koszt zatrudnienia N-tego pracownika danego typu**: `HIRE_BASE_COST[type] × HIRE_COST_GROWTH[type]^staff_count[type]` Sponsorów — eskalujący geometrycznie, ten sam kształt co typowa krzywa kosztów w grach idle.
4. **Mnożnik efektu ma malejący zwrot** względem `staff_count[type]` (dokładny kształt formuły w sekcji Formulas) — zapobiega nieskończonemu skalowaniu, tworzy naturalny punkt "lepiej zainwestować gdzie indziej".
5. **Sponsor Manager i Troll NIE idą przez ActionSystem reward resolution** — poprawione po `qa-lead` finding (pierwsza wersja tej reguły błędnie zakładała "trzecią warstwę po Class Path/Challenge w resolution nagród akcji", co koliduje z już zablokowanymi formułami F3b/F3c w `prestige-checkpoint-system.md`):
   - **Sponsor Manager** komponuje się w F3b (Sponsor income, "active-play only, card-resolution scoped"): wystawia pull-model getter `get_staff_sponsor_multiplier()`, wołany przez `DecisionCardSystem` przy rozwiązaniu karty sponsorskiej — ten sam wzorzec co `ClassPathSystem.get_active_sponsor_multiplier()` (ADR-0010 §5a), NIE `ActionSystem`.
   - **Troll** komponuje się w F3c (Haters growth rate, `H_rate_final = H_rate(C) × (1 − META_HATERS_RESIST_total)`) jako dodatkowy multiplikatywny czynnik obok `META_HATERS_RESIST` — wystawia pull-model getter `get_staff_haters_multiplier()`. F3c stosuje się identycznie online i offline (locked scope, `prestige-checkpoint-system.md`) — Troll dziedziczy ten sam zakres. **Uczciwa uwaga**: live-play call site dla całej tej rury (H_rate(C) × META_HATERS_RESIST) jeszcze nie istnieje w `ActionSystem` nawet bez Staff (`prestige_formulas.gd`'s własny doc comment: "ActionSystem currently has no live Haters-rate call site at all") — to pre-existing luka, poza zakresem tego GDD do naprawienia; Troll tylko rezerwuje swoje miejsce w tym łańcuchu mnożenia na przyszłość.
6. **Asystent stosuje się wewnątrz `OfflineProgressSystem.simulate_offline()`** jako ogólny mnożnik tempa offline — osobna ścieżka obliczeniowa, nie stackuje się z Formułą A/B/D żywej gry (Asystent nie ma efektu podczas aktywnej sesji, tylko offline).
7. **Zatrudnianie to natychmiastowa akcja**, bez czasu trwania — spójne z resztą ekonomii Sponsorów (Sponsor Shield też jest instant, `sponsor-network-shield-2026-06-30.md`).

### States and Transitions

Per typ pracownika:

| Stan | Warunek | Przejście |
|---|---|---|
| Affordable | Sponsory ≥ koszt N-tego pracownika | Tap → hire, `staff_count[type] += 1`, koszt N-tego przelicza się na N+1-ty |
| Unaffordable | Sponsory < koszt N-tego pracownika | Przycisk disabled — widoczny, nie ukryty (Locked/Muted Slot convention, `interaction-patterns.md`) |
| Era Reset | Wypalenie zaakceptowane | `staff_count[type] → 0` dla wszystkich trzech typów, w tej samej klatce co reszta era-local resetu (Core Rule 7, `prestige-checkpoint-system.md`) |

### Interactions with Other Systems

- **Resource System** (hard, read+write) — czyta Sponsory przy sprawdzaniu affordability, `apply_delta()` przy zatrudnieniu.
- **Decision Card System** (hard, read) — **poprawione po `qa-lead` finding**: konsumuje Sponsor Manager multiplier przy rozwiązaniu karty sponsorskiej (F3b), pull-model getter, ten sam wzorzec co `ClassPathSystem.get_active_sponsor_multiplier()` (ADR-0010 §5a).
- **Prestige Formulas / whoever wire'uje F3c** (soft, read) — Troll multiplier komponuje się do `H_rate_final` obok `META_HATERS_RESIST` (F3c); live-play call site dla tej rury jest pre-existing luką poza zakresem tego GDD (patrz Core Rule 5).
- **Offline Progress System** (hard, read) — konsumuje Asystent multiplier wewnątrz `simulate_offline()` (osobna ścieżka od żywej gry) ORAZ Troll's F3c-composed multiplier (już wpięte tam dla `META_HATERS_RESIST`, `offline_progress_system.gd:117`).
- **Prestige/Checkpoint System** (hard, write trigger) — wywołuje ten system's era-reset (analogicznie do `ClassPathSystem.reset_era_state()`) w ramach `_sweep_era_local_flags()`-owej sekwencji przy Wypaleniu.
- **Class Path System, Challenge System** (peer, brak bezpośredniego sprzężenia) — równoległe warstwy multiplikatywne na tym samym reward-resolution punkcie; kolejność stackowania udokumentowana (Core Rule 5), ale zero wywołań między systemami.

## Formulas

> *Specialists consulted: `systems-designer` (formula design), `economy-designer` (balance validation against real Sponsors economy) — Section D is HIGH-risk, consulted even in Lean mode.*

### Formula 1 — Staff Effect Multiplier

The `staff_multiplier` formula is defined as:

`staff_multiplier(type, n) = 1.0 + (MAX_MULTIPLIER[type] − 1.0) × [n / (n + STAFF_HALF_POINT[type])]`

Rectangular-hyperbola (Michaelis-Menten) shape — same "converging series" family as Class Path's `tier_factor()`, but shaped for an unbounded input domain (`staff_count` has no hard ceiling the way Class Path tier does, so the curve itself supplies the ceiling instead of the domain).

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| type | — | enum | `{troll, assistant, sponsor_manager}` | Which staff role's multiplier is being computed |
| n | `n` | int | `[0, ∞)` | `staff_count[type]` — current era-local hire count for that type |
| MAX_MULTIPLIER | — | float (tuning, per-type) | `(1.0, ~3.0]` | Asymptotic ceiling the multiplier approaches as n→∞, never reaches |
| STAFF_HALF_POINT | — | float (tuning, per-type) | `[1, 20]` | Hire count at which the multiplier reaches half of its total bonus range |

**Output Range:** `[1.0, MAX_MULTIPLIER[type])` — strictly bounded, never reaches the ceiling for any finite n. At n=0, exactly 1.0 (no staff, no effect).

**Defaults:**
| type | MAX_MULTIPLIER | STAFF_HALF_POINT |
|---|---|---|
| troll | 2.5 | 4 |
| assistant | 2.0 | 5 |
| sponsor_manager | 2.0 | 4 |

**Worked example** (troll): n=0 → 1.0; n=1 → 1.30; n=4 → 1.75 (exact midpoint by construction); n=10 → 2.07; n=50 → 2.39 (still climbing, compressing hard toward 2.5).

**Capped, not unbounded** (design decision, per `systems-designer`): every other stacking-bonus formula in this project has an explicit cap (`META_BONUS_MAX`, `CARD_CONTRIBUTION_MAX`) — an unbounded staff multiplier would be the first exception and would blow past every other system's tuning assumptions given `staff_count` has no natural domain ceiling (unlike Class Path's tier 0-5).

### Formula 2 — Hire Cost

The `hire_cost` formula is defined as:

`hire_cost(type, n) = HIRE_BASE_COST[type] × HIRE_COST_GROWTH[type]^n`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| type | — | enum | `{troll, assistant, sponsor_manager}` | Staff role being hired |
| n | `n` | int | `[0, ∞)` | `staff_count[type]` BEFORE this hire — cost of hiring the (n+1)-th member |
| HIRE_BASE_COST | — | float (tuning, per-type) | `[3, 10]` | Cost of the 1st hire (n=0) |
| HIRE_COST_GROWTH | — | float (tuning, per-type) | `[1.3, 2.0]` | Per-hire geometric growth rate |

**Output Range:** `[HIRE_BASE_COST[type], ∞)`, strictly increasing, deliberately unbounded — the escalating cost is what makes late hires a real investment decision, and Sponsors previously had no meaningful sink (registry: "No consumption sink yet").

**Defaults** (reasoned against the real Sponsors economy — only 2/12 card types yield Sponsors, avg ~2 per qualifying draw, `SHIELD_COST=5` ≈ 1 reference "shield-unit"):
| type | HIRE_BASE_COST | HIRE_COST_GROWTH |
|---|---|---|
| troll | 4 | 1.6 |
| assistant | 5 | 1.6 |
| sponsor_manager | 6 | 1.7 (faster — dampens the self-referential income loop, see Core Rule 1) |

**Worked examples**: troll n=0→4, n=1→6.4, n=4→26.2, n=8→171.8. Sponsor Manager n=0→6, n=1→10.2, n=4→50.1, n=8→418.6.

**Rounding rule (locked)**: `hire_cost()` returns a float; Sponsors is an integer currency elsewhere in the economy — the call site MUST `ceil()` the result, never round down (no underpaying on a rounding edge).

**Economic validation** (`economy-designer`): hire 1 (4-6 Sponsors) ≈ 1 shield-unit, affordable within a session or two — correct per intent. Hire 4 (26-50 Sponsors) ≈ 5-10 shield-units, appropriate mid-session investment. Hire 8 (172-419 Sponsors) ≈ 34-84 shield-units (~500-1300+ card draws at the real qualifying-card rate) — **reachability within a single era is unverified, no era-duration data exists yet to check against; see Open Questions.** Shield vs. staff sink competition creates genuine trade-off tension (both draw from the same scarce Sponsors pool), not domination of one over the other — matches Pillar 4 intent.

### Formula 3 — Troll Composition into F3c (`H_rate_final`)

**Added per `qa-lead` finding** — explicit composition formula, so Troll's interaction with the already-locked `META_HATERS_RESIST` (F3c, `prestige-checkpoint-system.md`) is stated, not inferred:

`H_rate_final = H_rate(C) × staff_multiplier(troll, n) × (1 − META_HATERS_RESIST_total)`

Multiplication is commutative — order doesn't change the result — but this GDD states the composition explicitly so a test has one stated formula to assert against. `H_rate(C)` is `ResourceFormulas.haters_growth_rate(cringe)`, already computed by the caller. Same online/offline scope as F3c (locked): applies identically in both contexts, once the pre-existing live-play call-site gap (Core Rule 5) is eventually closed by whoever owns that follow-up.

## Edge Cases

- **Jeśli `staff_count[type] == 0`**: `staff_multiplier` zwraca dokładnie `1.0` — brak efektu, brak specjalnej ścieżki kodu.
- **Jeśli gracz chce mieć mniej pracowników danego typu**: niemożliwe w trakcie ery — zatrudnienie jest jednokierunkowe do następnego resetu, spójne z framingiem "decyzja inwestycyjna" (Player Fantasy). Brak mechaniki zwalniania.
- **Jeśli przyszły balance patch zmieni `MAX_MULTIPLIER[type]`**: `staff_multiplier` jest liczony live z `staff_count` przy każdym odczycie, nigdy nie akumulowany/zapisywany jako oddzielna wartość (w przeciwieństwie do Prestige's `META_BONUS_total`) — nowy cap stosuje się natychmiast do wszystkich aktywnych graczy, bez potrzeby migration policy jaką ma Prestige F2.
- **Wypalenie nie może wyzwolić się podczas offline simulation** (Cringe timer nie inkrementuje offline, już ustalone w `final-burnout-2026-07-01.md` Core Rule 1) — `staff_count` nigdy nie resetuje się w środku `simulate_offline()`, tylko na granicy sesji (live play only).

## Dependencies

**Upstream (ten system zależy od):**
- **Resource System** (hard) — Sponsory jako waluta, `apply_delta()` przy zatrudnieniu.
- **Offline Progress System** (hard) — Asystent multiplier konsumowany wewnątrz `simulate_offline()`.
- **Prestige/Checkpoint System** (hard) — triggeruje era-lokalny reset `staff_count`. **Ten GDD rozwiązuje zablokowany wymóg** z `prestige-checkpoint-system.md` ("Zero-sink Sponsor scope decision", `/design-review` 2026-07-13): `META_BONUS_MAX[META_SPONSOR_MULT]` (0.50) i `[META_SPONSOR_FLOOR]` (100.0) pozostają bez zmian po re-examination — oryginalny niepokój dotyczył PRZEPŁYWU (Sponsory piętrzące się w żywej grze bez sinka), nie STANU (permanentne totale już capped przez F2). `hire_cost()`'s nieograniczony, eskalujący sink dostarcza dokładnie brakujący element przepływu per-era.

**Downstream (zależy od tego systemu):**
- **Decision Card System** — będzie konsumować Sponsor Manager multiplier przy card-resolution (F3b, po zaimplementowaniu).
- **Offline Progress System / F3c's live-play wiring** — będzie konsumować Troll multiplier jako część `H_rate_final` (po zaimplementowaniu tej pre-existing luki, poza zakresem tego GDD).
- **Staff/Sponsor UI** (systems-index #16, Not Started) — powierzchnia UI dla tego systemu.

## Tuning Knobs

| Knob | Default (troll/assistant/sponsor_manager) | Range | Co się psuje na skrajnościach |
|---|---|---|---|
| `MAX_MULTIPLIER[type]` | 2.5 / 2.0 / 2.0 | `(1.0, ~3.0]` | `1.0` → zero efektu, cały system bez sensu. Powyżej ~3.0 → ryzyko dominacji nad Class Path/Challenge warstwami w tej samej formule stackowania. |
| `STAFF_HALF_POINT[type]` | 4 / 5 / 4 | `[1, 20]` | Bardzo niskie (1) → multiplier prawie od razu blisko capu, pierwsza inwestycja czuje się jak ostatnia. Bardzo wysokie (20) → wczesne hire'y prawie niewyczuwalne, zabija motywację do zaczęcia. |
| `HIRE_BASE_COST[type]` | 4 / 5 / 6 | `[3, 10]` | Zbyt nisko → pierwszy hire trywialny, brak decyzji. Zbyt wysoko → gracz nigdy nie dociera do progu wejścia w system. |
| `HIRE_COST_GROWTH[type]` | 1.6 / 1.6 / 1.7 | `[1.3, 2.0]` | `1.0` → brak eskalacji, złamany sink (Sponsory znów bez realnego ograniczenia). Powyżej ~2.0 → system praktycznie kończy się po 3-4 hire'ach, formuła malejącego zwrotu nigdy nie zdąży się rozwinąć. |

Wszystkie wartości muszą żyć w `assets/data/balance.json` (lub równoważnym), nie hardcoded — ten sam wzorzec co pozostałe GDD tego projektu.

## Visual/Audio Requirements

Reużywa istniejącego dashboard aesthetic (`art-bible.md`) — 3 typy pracowników różnicowane ikoną/etykietą, NIE kolorem (no-valence rule, §1). Liczniki `staff_count` i koszt następnego hire zawsze tekstowe, nigdy tylko wizualne. Zatrudnienie to instant akcja (Core Rule 7) — brak animacji trwania, ewentualny krótki potwierdzający beat (self_modulate flash, ten sam kanał co inne resource-changed reakcje) do doprecyzowania przy `/asset-spec`.

**Audio**: brak. Gra ma trwale zablokowane audio (decyzja 2026-07-12).

📌 **Asset Spec** — once the art bible confirms icon needs for 3 staff types, run `/asset-spec system:team-staff-management`.

## UI Requirements

Nowy panel: **Staff/Sponsor UI** (systems-index #16, Not Started) — 3 wiersze pracowników (nazwa/liczba zatrudnionych/koszt następnego hire/przycisk Hire), ten sam wzorzec wizualny co `ClassPathPanel`. Disabled Hire (Unaffordable state) reużywa `Disabled-State Tooltip` (`interaction-patterns.md`). Nawigacja: prawdopodobnie czwarty/piąty panel `MainNavCoordinator`-owy (wzorem `BonusesPanel`, ADR-0014) — dokładna decyzja należy do `/ux-design`, nie do tego GDD.

> **📌 UX Flag — Team/Staff Management**: Ten system ma wymagania UI. Uruchom `/ux-design` dla Staff/Sponsor UI przed pisaniem epics/stories — stories referencing UI powinny cytować `design/ux/staff-sponsor-ui.md`, nie ten GDD bezpośrednio.

## Acceptance Criteria

*Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**Testability note**: `DecisionCardSystem`'s consumption of the Sponsor Manager multiplier, `OfflineProgressSystem`'s consumption of the Assistant and Troll multipliers, and `PrestigeSystem`'s era-reset trigger into this system are all "will read" — none of these hooks are built yet, and this GDD's own Autoload doesn't exist yet either. Integration criteria below are **BLOCKING against mocked collaborators** (mocked `ResourceManager`, mocked `DecisionCardSystem`, mocked `OfflineProgressSystem`, mocked era-transition emitter) — same pattern as `class-path-system.md`'s Era Reset section. These convert to real integration tests once the consuming systems exist.

### Formula 1 — Staff Effect Multiplier (`staff_multiplier`)

- **GIVEN** `staff_count[troll] = 0`, **WHEN** `staff_multiplier(troll, 0)` is called, **THEN** it returns exactly `1.0` — confirmed identically for `assistant`/`sponsor_manager` at n=0, not just troll. **[Logic — BLOCKING]**
- **GIVEN** `staff_count[troll] = 1 / 4 / 10 / 50`, **WHEN** `staff_multiplier(troll, n)` is called, **THEN** it returns `1.30 / 1.75 / 2.07 / 2.39` respectively, confirming n=4 lands exactly on troll's stated half-point midpoint. **[Logic — BLOCKING]**
- **GIVEN** `staff_count[assistant] = 5` (assistant's own STAFF_HALF_POINT=5, MAX_MULTIPLIER=2.0), **WHEN** `staff_multiplier(assistant, 5)` is called, **THEN** it returns exactly `1.5` — confirms per-type constants, not hardcoded to troll's defaults. **[Logic — BLOCKING]**
- **GIVEN** the marginal gain from n=0→1 (Δ=0.30) vs. n=49→50 (Δ≈0.0021), **THEN** the later marginal gain is over 100x smaller — confirms diminishing returns (Core Rule 4), not just an asymptote claim. **[Logic — BLOCKING]**

### Formula 2 — Hire Cost (`hire_cost`) and the Locked `ceil()` Rule

- **GIVEN** `staff_count[troll] = 0 / 1 / 4 / 8`, **WHEN** `hire_cost(troll, n)` is called and the locked rounding rule applies, **THEN** it charges `4 / 7 / 27 / 172` Sponsors (raw `4.0 / 6.4 / 26.21 / 171.8`, each rounded up). **[Logic — BLOCKING]**
- **GIVEN** `staff_count[sponsor_manager] = 1 / 4`, **WHEN** `hire_cost(sponsor_manager, n)` is called, **THEN** it charges `11 / 51` Sponsors — confirms the faster 1.7 growth rate is applied, not troll's 1.6. **[Logic — BLOCKING]**
- **GIVEN** `hire_cost(troll, 1)` raw output is `6.4`, **WHEN** the call site charges the player, **THEN** it charges exactly `7`, not `6` — the one input value that distinguishes "ceil() implemented" from a less careful rounding function. **[Logic — BLOCKING]**

### Formula 3 — Troll Composition into F3c

- **GIVEN** `META_HATERS_RESIST_total = 0.30` and `staff_count[troll] = 4` (multiplier 1.75), **WHEN** `H_rate_final` is computed, **THEN** it equals `H_rate(C) × 1.75 × 0.70` — both factors compose multiplicatively, neither overrides the other. **[Logic — BLOCKING]**

### Affordable / Unaffordable State Gating

- **GIVEN** Sponsors=6, `staff_count[troll]=0` (cost=4), **THEN** state is Affordable, Hire control enabled; **WHEN** tapped, **THEN** Sponsors→2, `staff_count[troll]→1`, displayed next cost recomputes to `hire_cost(troll,1)=7`. **[Integration — BLOCKING, mocked ResourceManager]**
- **GIVEN** Sponsors=6, `staff_count[troll]=1` (next cost=7), **THEN** state is Unaffordable — Hire control visible but disabled (Locked/Muted Slot convention); **WHEN** tapped anyway, **THEN** no Sponsors deduction, no `staff_count` change. **[Integration — BLOCKING]**
- **GIVEN** Sponsors exactly equal `hire_cost()`'s ceil'd value, **THEN** state is Affordable — confirms the gate is `≥`, not `>`. **[Logic — BLOCKING]**

### Era Reset (Core Rule 2, States table)

- **GIVEN** `staff_count[troll]=6, [assistant]=3, [sponsor_manager]=2` when Wypalenie Choice A resolves, **WHEN** the era-local reset sweep completes, **THEN** all three read exactly `0`, same sweep as Class Path affiliation — no staff type exempt. **[Integration — BLOCKING, mocked era-transition emitter]**

### Sponsor Manager Scope Lock (Core Rule 1, economy-designer finding)

- **GIVEN** identical Cringe-eligibility state, **WHEN** `DecisionCardSystem`'s card-pool weights are computed with `staff_count[sponsor_manager]=0` vs. `=10`, **THEN** weights/probabilities of every card are identical in both runs — Sponsor Manager has zero read access to card-weighting. **[Integration — BLOCKING]** *(regression guard for the two-loop feedback risk Core Rule 1 explicitly rejects)*
- **GIVEN** `staff_count[sponsor_manager]=n>0` and a qualifying card resolves with `base_sponsors_roll=3`, **WHEN** the Sponsor amount is computed, **THEN** only the rolled amount is scaled by `staff_multiplier(sponsor_manager,n)` — across repeated trials, qualifying-card draw *rate* is statistically unaffected. **[Integration — BLOCKING]**

### No Firing / Un-hire Mid-Era (Edge Cases)

- **GIVEN** `staff_count[troll]=N` mid-era, **THEN** no exposed API or UI control ever decrements it — the only path from N to lower is a full era reset to 0. **[Logic — BLOCKING]**

### Instant Hire, No Duration (Core Rule 7)

- **GIVEN** the player taps an affordable Hire control, **WHEN** the tap resolves, **THEN** `staff_count[type]` increments and cost recomputes in the same frame — no pending state, no tween-gated delay. **[Integration — BLOCKING]**

### Live Recomputation, No Caching (Edge Cases)

- **GIVEN** `MAX_MULTIPLIER[troll]` changes via balance-data hot-reload mid-session while `staff_count[troll]` stays unchanged, **WHEN** `staff_multiplier(troll,n)` is next queried, **THEN** it reflects the new cap immediately — confirms live computation, never cached (unlike Prestige's `META_BONUS_total`). **[Logic — BLOCKING]**

### `staff_count` Immunity to Offline Simulation (Edge Cases)

- **GIVEN** `staff_count[type]` holds nonzero values immediately before `simulate_offline()` runs, **WHEN** the simulation completes, **THEN** all three values are unchanged — no era-reset can fire mid-simulation. **[Logic — BLOCKING]**

### Assistant Scope — Offline-Only (Core Rule 6)

- **GIVEN** `staff_count[assistant]>0`, **WHEN** a live-session action resolves via Formula A/B/D, **THEN** the assistant multiplier is never queried, has no effect on the result. **[Integration — BLOCKING]**
- **GIVEN** the same `staff_count[assistant]`, **WHEN** `simulate_offline()` runs, **THEN** the assistant multiplier applies as the general offline-tempo multiplier inside that separate calculation path. **[Integration — BLOCKING, mocked OfflineProgressSystem]**

### Role Distinctness (Core Rule 1)

- **GIVEN** the same n, **WHEN** `staff_multiplier` is computed for troll/assistant/sponsor_manager in turn, **THEN** the three outputs differ (per distinct defaults) — confirms three independent curves, not one shared instance. **[Logic — BLOCKING]**

### Live-Play Application Hooks (Core Rule 5, corrected)

- **GIVEN** `staff_count[sponsor_manager]>0`, **WHEN** `DecisionCardSystem` resolves a sponsor-qualifying card, **THEN** it reads the Staff system's pull-model getter (`get_staff_sponsor_multiplier()`-shaped) directly — NOT via `ActionSystem`. **[Integration — BLOCKING against mocked DecisionCardSystem]**
- **GIVEN** `staff_count[troll]>0`, **WHEN** `H_rate_final` is computed (Formula 3), **THEN** Troll's multiplier is read via a pull-model getter composed alongside `META_HATERS_RESIST`, not through any Action-reward-resolution pipeline. **[Logic — BLOCKING]**

## Open Questions

- **Osiągalność hire tier 7-8 w jednej erze niezweryfikowana** (`economy-designer` finding) — brak danych o typowej długości ery (czas do Wypalenia) do zweryfikowania czy 172-419 Sponsorów (~500-1300+ card draws) jest w ogóle osiągalne przed resetem. *Owner: economy-designer, po zebraniu realnych danych o długości ery z Vertical Slice playtestów. Target: przed Alpha.*
- **Pre-existing luka: brak live-play call site dla `H_rate(C) × META_HATERS_RESIST`** — znaleziona w `prestige_formulas.gd`'s własnym doc comment, nie stworzona przez ten GDD. Troll's multiplier (Formula 3) rezerwuje miejsce w tym łańcuchu, ale nie działa w żywej grze dopóki ta luka nie zostanie domknięta przez kogoś innego. *Owner: nieprzypisany, pre-existing przed tym GDD.*
- **Brak twardego capu na `staff_count[type]`** (`qa-lead` finding) — tylko miękkie ograniczenie przez eskalujący koszt i malejący zwrot multipliera. Non-blocking, ale warte rozważenia jeśli playtesty pokażą degenerate late-era strategie. *Owner: nieprzypisany.*
- **Dokładny kształt Staff/Sponsor UI** (który panel, jak nawigacja, MainNavCoordinator-owy czy nie) — odroczone do `/ux-design`, nie rozstrzygnięte tutaj.
