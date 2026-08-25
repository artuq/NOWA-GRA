# Cosmetic Persona Customization

> **Status**: Designed (revised post-review — see Revision Log below)
> **Author**: user + agents
> **Last Updated**: 2026-07-23
> **Implements Pillar**: Brak bezpośredniego mapowania na Pillar 1-4 (czysta ekspresja tożsamości, nie mechanika rdzenia) — wspiera pośrednio Pillar 2 (decyzje mają pamięć: kosmetyki są widocznym, permanentnym śladem historii ścieżek klasy, równolegle do META_BONUS) i Pillar 3 (satyra: kosmetyki jako komentarz do "budowania marki osobistej" influencera, nigdy jako power creep).

## Revision Log

**2026-07-23 — post `/design-review` (full mode, 6 specialists + creative-director synthesis).** Verdict: NEEDS REVISION → revised in-session. Six blocking findings addressed:

1. **Collector-fantasy claim overstated for 10/20 slots** — `ekspert_niszowy`/`biznesmen_contentu` have zero tagged cards, making half the table structurally unreachable today. Caveat added to Edge Cases; ownership tracked in Open Questions, not silently left as-is.
2. **Third corrupted-save boundary case uncovered** — a `cosmetic_id` whose `slot` was reassigned by a content edit since the save was written fell into neither existing Edge Case. Added as its own case with a `restore_state()` slot re-validation rule.
3. **Content-table integrity had no CI lint** beyond the face-lock special case — added a lint AC covering duplicate `unlock_milestone` values and orphaned slot enums.
4. **Color-only slots (`FrameColor`/`BackgroundFill`) had no accessibility check** — added a grayscale-distinguishability requirement and a contrast-safety requirement against the fixed face/accessory outline, matching the standard already applied elsewhere in this project's color-banned UI.
5. **Naming convention collision** — `char_avatar_[slot]_[cosmetic_id].png` conflicted with art-bible §8's already-locked `icon_[category]_[name].png` scheme (which reserves `avatar` as a `system` category). Renamed to `icon_avatar_[slot]_[cosmetic_id].png`.
6. **Unlock-signal requirement reopened and reversed** — the same-day lock mandating a persistent push-badge was found, on adversarial review, to be a pattern this project has never used elsewhere and in tension with the "precision without judgment" tone. Downgraded to a pull-based-only constraint; exact mechanism still deferred to `/ux-design`.

Also folded in: `equip_cosmetic()`'s bare-bool return and the equipped-loadout save schema are now explicitly flagged as implementation decisions deferred to ADR/architecture rather than locked in this GDD; several AC classification fixes (Content-Lint vs. Logic vs. Integration); a general "exactly one cosmetic per slot" invariant AC; a bidirectional-dependency fix on `history-flag-system.md`; and two non-blocking Open Questions on mix-and-match archetype dilution and the unverified "warmth through agency, not hierarchy" design bet.

## Overview

Cosmetic Persona Customization to warstwa czysto wizualna, w której gracz personalizuje swój avatar (akcesorium, kolor ramki, wypełnienie tła) bez żadnego wpływu na mechanikę — czysta ekspresja tożsamości. Interakcja: aktywna, dobrowolna, kiedy gracz chce. Bez tego systemu Class Path progression (która już produkuje różne "persony" jak Trash Streamer T4) nie ma żadnej wizualnej ekspresji poza tekstem/numerem tieru — brak sposobu żeby gracz poczuł "to jest MÓJ gość" oddzielnie od statystyk. Dodatkowo daje nie-mocową nagrodę (kosmetyki jako reward zamiast czystego power creep, który już obsługuje META_BONUS).

## Player Fantasy

"To MÓJ influencer, nie generyczny numer na dashboardzie." Jedyny ciepły, osobisty akcent w inaczej chłodnej, numerycznej estetyce gry — ale musi zostać w ryzach Anti-Pillar 2 (kosmetyki wyrażają tożsamość, nigdy moc ani moralność). Nie jest to system działający w tle — gracz aktywnie wybiera, widzi efekt natychmiast.

## Detailed Design

### Core Rules

1. **Trzy sloty kosmetyczne**: `Accessory` (akcesorium/czapka), `FrameColor` (kolor ramki avatara), `BackgroundFill` (wypełnienie tła chipa) — dokładnie te trzy, per art-bible.md §5's "cosmetic layering rule". Twarz/ekspresja avatara jest zablokowana na stałe (single deadpan baseline, nigdy niekostomizowalna — zmiana ekspresji byłaby valence signal, zakazana przez art-bible §1).
2. **Odblokowanie przez Class Path Tier progression**: każda kombinacja (ścieżka, tier 1-5) odblokowuje dokładnie jedną opcję kosmetyczną, per statyczna tabela `(path_id, tier) → cosmetic_id`. 4 ścieżki × 5 tierów = do 20 możliwych odblokowań.
3. **Odblokowanie wyprowadzone na żywo z już istniejącej infrastruktury** — sprawdzane przez `HistoryFlagManager.has_milestone(StringName("class_path." + path_id + ".best_tier." + str(tier)))`, milestone już zapisywany przez `ClassPathSystem.reset_era_state()` (shipped, `class_path_system.gd:510`). **Zero nowego API na `ClassPathSystem` potrzebne** — ten system czyta wyłącznie już-shipped `HistoryFlagManager` milestone'y.
4. **Odblokowanie jest permanentne** — nigdy nie jest zapisywane osobno jako własny stan, tylko wyprowadzane na żywo z milestone'a (który sam jest już meta-persystentny, przetrwał każdy reset ery od momentu wprowadzenia). Brak potrzeby własnej logiki trwałości dla "co odblokowane".
5. **Equipped loadout to nowy, mały persystowany stan** — który konkretny `cosmetic_id` jest aktualnie założony per slot (3 pola). Niezależne od aktywnej ścieżki w danej erze (mix-and-match już zatwierdzone) — equipped `Accessory` może pochodzić z zupełnie innej ścieżki niż equipped `FrameColor`. **Design-review note (2026-07-23, game-designer finding)**: dopuszczalne bez ograniczeń, ale nigdy nie skonfrontowane z Pillar 3 — mieszanie sylwetek z różnych archetypów może rozmywać czytelność "widocznie jestem tym typem" w kosmetyczną mieszankę. Brak zmiany reguły w tym przejściu, tylko odnotowanie tradeoffu (zob. Open Questions). Publiczne API: `equip_cosmetic(slot: StringName, cosmetic_id: StringName) -> bool` (zwraca `false`, brak mutacji, jeśli (a) `cosmetic_id` jest `Locked`, (b) jego `slot` w tabeli nie zgadza się z parametrem `slot` — slot-mismatch to twarde odrzucenie, nie ciche dopasowanie, LUB (c) `cosmetic_id` nie istnieje w tabeli wcale — trzy rozłączne warunki odrzucenia, ten sam `false`/brak-mutacji kontrakt dla wszystkich). **Design-review note (2026-07-23, systems-designer/godot-gdscript-specialist finding)**: bare `bool` collapsuje trzy rozłączne przyczyny odrzucenia w jeden nieprzezroczysty wynik — wystarczające dla UI (nigdy nie oferuje zablokowanej/nieistniejącej opcji), niewystarczające dla przyszłych narzędzi debug/telemetrii. Dokładny kształt zwracanej wartości (bool vs. enum z rozróżnionymi przyczynami) to decyzja implementacyjna dla ADR/architektury, nie dla tego GDD — ten dokument definiuje CO system robi (trzy rozłączne warunki odrzucenia), nie JAK jest to sygnalizowane w kodzie. `get_unlocked_ids() -> Array[StringName]` (do renderowania listy odblokowanych opcji per slot). **Zalecany kształt zapisu (niewiążący, dla ułatwienia implementacji)**: `Dictionary` kluczowany nazwą slotu (`Accessory`/`FrameColor`/`BackgroundFill`) → `StringName` cosmetic_id, brak klucza gdy nic nie założone — ten sam wzorzec co `class_path_system.gd`'s `serialize_state()`/`restore_state()` (String klucze, StringName wartości rekonstruowane przy wczytaniu).
6. **Domyślny stan (zero odblokowań)**: baseline deadpan avatar, żaden slot nie ma nic założonego — zgodne z art-bible's "single deadpan baseline face" default.

### States and Transitions

Per `cosmetic_id`:

| Stan | Warunek | Przejście |
|---|---|---|
| Locked | Odpowiedni milestone niesetowany | → Unlocked, gdy `HistoryFlagManager.has_milestone(...)` zwróci `true` (jednokierunkowe, nieodwracalne — milestone nigdy się nie czyści) |
| Unlocked | Milestone setowany, nie założony w żadnym slocie | → Equipped (gracz zakłada) LUB pozostaje Unlocked |
| Equipped | Założony w swoim slocie (`Accessory`/`FrameColor`/`BackgroundFill`) | → Unlocked (gracz zmienia na inny kosmetyk w tym slocie), zawsze odwracalne w obie strony |

### Interactions with Other Systems

- **Class Path System** (soft, read) — tylko jako źródło koncepcyjne milestone'ów (path/tier taksonomia); zero bezpośredniego wywołania do `ClassPathSystem` samego — wszystko idzie przez `HistoryFlagManager`.
- **History Flag Manager** (hard, read) — `has_milestone("class_path.{path}.best_tier.{N}")`, już istniejące API, żadnych zmian.
- **Save System** (hard, write) — equipped loadout (3 pola) jest jedynym nowym stanem tego systemu wymagającym persystencji.

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

Ten GDD nie wprowadza żadnej matematyki gry ani wyprowadzenia liczbowego — zgodnie z Anti-Pillar 2 ("kosmetyki nigdy nie niosą znaczenia liczbowego"), ten sam precedens co `main-navigation-screen-flow.md`. Zero zmiennych, zero wyprowadzeń.

Potwierdzone przez `systems-designer`: (a) jednoczesne odblokowanie wielu tierów w tej samej klatce to pytanie o stan (idempotentne, kolejność-niezależne sprawdzenia `has_milestone()`), nie o formułę; (b) domyślny wygląd niezałożonego slotu to statyczny fallback asset (`default_[slot].png`), nie wartość wyprowadzona; (c) tabela 20 wpisów (`cosmetic_id`, `slot`, `path`, `tier`, `unlock_milestone`) to płaska, ręcznie autorowana treść, nie logika generatywna.

## Edge Cases

- **Era reset NIE wpływa na equipped loadout** — niezależne od aktywnej ścieżki w danej erze (mix-and-match, Core Rule 5), przetrwa każdy reset bez żadnej specjalnej obsługi.
- **Milestone nigdy się nie czyści** — "odblokowany kosmetyk staje się z powrotem zablokowany" to scenariusz strukturalnie niemożliwy do wystąpienia (`HistoryFlagManager` milestone'y są jednokierunkowe), nie wymaga obsługi.
- **Fresh save (0 odblokowań)**: wszystkie 20 opcji widoczne jako zablokowane (Locked/Muted Slot convention, `interaction-patterns.md`), nigdy ukryte — buduje kolekcjonerską fantazję ("wiem że tam coś jest, jeszcze tego nie mam"). **Design-review caveat (2026-07-23, game-designer finding — blocking)**: ta fantazja jest dziś częściowo fałszywa dla 10 z 20 wpisów — `ekspert_niszowy` i `biznesmen_contentu` mają zero otagowanych kart (zob. Open Questions), więc te sloty są strukturalnie nieosiągalne, nie "jeszcze nieodblokowane". Ten Edge Case pozostaje poprawny mechanicznie (wszystko widoczne, nic ukryte), ale samo tekstowe uzasadnienie ("jeszcze tego nie mam") nie powinno być czytane jako prawdziwe dla całych 20 wpisów dopóki content-authoring gap nie zostanie zamknięty — patrz Open Questions dla ownera i statusu.
- **Brak klucza equipped-loadout w save**: domyślnie baseline (zero założonych kosmetyków), ten sam missing-key-default wzorzec co każdy inny peer Autoload w projekcie.
- **Persystowany equipped `cosmetic_id`, którego milestone przy wczytaniu czyta `false`** (corrupted/ręcznie edytowany save) — `restore_state()` NIGDY nie re-waliduje przeciw `has_milestone()`; persystowana wartość jest zaufana bezwarunkowo, tak jak reszta save-state w tym projekcie. Praktycznie niemożliwe w normalnej grze (milestone'y nigdy się nie czyszczą), ale jawnie rozstrzygnięte, nie pozostawione niezdefiniowane.
- **Persystowany equipped `cosmetic_id`, który nie istnieje w ogóle w aktualnej tabeli treści** (usunięty przyszłą edycją contentu, literówka, ręczna edycja save'a) — odrębny przypadek od powyższego (tam milestone czyta `false`, ale wpis w tabeli wciąż istnieje; tu wpisu nie ma wcale, więc nawet slot/milestone nie da się odczytać). `restore_state()` traktuje ten przypadek jak brakujący equipped-loadout dla tego konkretnego slotu: reset do baseline (nic założone), bez crasha — ten sam missing-key-default wzorzec co reszta save-state w projekcie, zastosowany per-slot zamiast na całym stanie.
- **Persystowany equipped `cosmetic_id`, który wciąż istnieje w tabeli, ale jego `slot` został przepięty przez późniejszą edycję contentu** (added 2026-07-23, design-review — systems-designer finding, blocking) — trzeci, wcześniej nieobsłużony przypadek, odrębny od obu powyższych: milestone może czytać `true`, wpis wciąż istnieje, ale zapisany w save slot (np. `Accessory`) już nie zgadza się z aktualnym `slot` tego wpisu w tabeli (np. edycja contentu przeniosła go do `FrameColor`). `restore_state()` musi re-walidować `slot` per equipped entry przy wczytaniu (nie tylko istnienie `cosmetic_id`, jak w przypadku powyżej) — jeśli aktualny `slot` z tabeli nie zgadza się ze slotem, w którym wartość była zapisana, ten konkretny slot resetuje się do baseline, ten sam missing-key-default wzorzec co pozostałe przypadki. Odrębne od zwykłego equip-time slot-mismatch (Core Rule 5's `equip_cosmetic()` rejection) — to walidacja przy wczytaniu, nie przy aktywnym equipowaniu.

## Dependencies

**Upstream (ten system zależy od):**
- **History Flag Manager** (hard) — `has_milestone("class_path.{path}.best_tier.{N}")`, jedyne realne źródło danych o odblokowaniach.
- **Save System** (hard) — equipped loadout persistence (3 pola).
- **Class Path System** (soft, konceptualne) — źródło taksonomii path/tier używanej w tabeli unlock, ale zero bezpośrednich wywołań do `ClassPathSystem` samego — wszystko idzie przez `HistoryFlagManager`. **Rozwiązuje wcześniej niezdefiniowany kontrakt** flagowany w `class-path-system.md` Open Questions ("expected to read active path for cosmetic-flavor gating — no contract defined yet") — kontrakt okazał się węższy niż zakładano: nie "aktywna ścieżka", tylko już-shipped milestone'y, niezależnie od tego co aktualnie aktywne.

**Downstream (zależy od tego systemu):**
- Brak — najbardziej downstream element warstwy UI/Presentation w obecnym systems-index.

## Tuning Knobs

Brak — ta sama logika co Formulas: zero liczb do strojenia. Tabela 20 wpisów (`cosmetic_id`↔`path`↔`tier`) to autorowana treść, nie tuning knob — dodanie/zmiana kosmetyku to content-editing zadanie, nie balance-pass.

## Visual/Audio Requirements

> *Specialist consulted: `art-director` — category UI, mandatory for Visual/Audio.*

**Audio**: None. Ten system dziedziczy permanentną decyzję no-audio (2026-07-12) bez wyjątku — zdarzenia unlock i equip nie mają SFX.

**VFX — Unlock event**: reużywa istniejący wzorzec Resolution-payoff (art-bible §2) — krótki `self_modulate` brightness pulse na tokenie `color_activity` (`#E8E6F0`), szybki decay, na nowo-Unlocked wpisie. Bez konfetti, iskier, glow zależnego od "rzadkości" — przejście Locked→Unlocked to zmiana stanu, nie celebracja (art-bible §1, "precision without judgment").

**VFX — Equip/swap event**: natychmiastowy snap-apply na avatarze, bez morph/crossfade — spójne z §7's "ikony niosą zero wbudowanego ruchu". Feedback potwierdzający to ten sam brightness-pulse token, nie bespoke efekt.

**Zakaz kodowania rzadkości wizualnie**: żadnej hierarchii wizualnej między kosmetykami (złote/fioletowe ramki, skalowanie rozmiaru, intensywność glow per tier) — sugerowałoby to ranking wartości, czyli valence, zakazane przez Anti-Pillar 2 i §1.

**Ograniczenia autorskie dla 20 assetów** — **rozszerzenie zablokowanego 2026-07-11 stylu ikon (outline+flat fill, bez highlightu) na tę nową rodzinę assetów** (decyzja: spójność jednego języka graficznego w całej grze, nie osobny styl dla kosmetyków):
- Komponowane jako warstwy na już istniejącym 32×32 okrągłym avatar chipie (art-bible §5) — nigdy nie zmieniają rozmiaru ani nie zasłaniają stałej bazowej twarzy.
- Ta sama dyscyplina 2-tonowego outline+flat-fill co §7/§8 icon spec (gruby ciemny outline, płaski fill, zero gradientu/highlightu/AA, pixel-hard krawędzie).
- `FrameColor` **i** `BackgroundFill` jako palette-token swap — dla `FrameColor` na obrysie chipa, dla `BackgroundFill` na wypełnieniu chipa — żaden z nich nie potrzebuje osobnego PNG per wpis, data-driven, ten sam wzorzec co kolorowanie pigułek zasobów. **Rewizja (design-review 2026-07-23)**: `BackgroundFill` pierwotnie planowany jako hand-authored PNG bez uzasadnienia różnicy względem `FrameColor` — flat color-fill nie ma powodu być droższy w produkcji niż flat color-outline, więc oba sloty dzielą ten sam token-swap mechanizm. Redukuje autorski lift 20-assetowego zestawu (zob. Open Questions).
- `Accessory` jako jedyny slot z hand-authored, statycznymi płaskimi PNG overlayami; żadna sylwetka akcesorium nie może przekroczyć footprintu chipa (większe ≠ lepsze, Anti-Pillar 2). **Design-review note (2026-07-23, art-director finding)**: ten slot stackuje trzecią warstwę outline'u (chip outline + face outline + accessory outline) w tym samym gridzie 32×32, gdzie art-bible §7:110 już oznaczył jedną ikonę ("Launch a Course") jako highest-complexity wymagającą recheck przy tej skali — te same ryzyko-generujące sylwetki (czapka, okulary) dotyczą tego slotu i powinny przejść ten sam recheck przy `/asset-spec`, nie być zakładane jako bezproblemowe.
- Zero wbudowanego ruchu na jakimkolwiek asset kosmetycznym — ruch pozostaje wyłączną domeną systemu juice.
- **Nazewnictwo (poprawione 2026-07-23, design-review — art-director finding, blocking)**: `char_avatar_[slot]_[cosmetic_id].png` collidowało z już zablokowaną konwencją art-bible §8's `icon_[category]_[name].png`, która już rezerwuje `avatar` jako kategorię `system` (`assets/ui/icons/`). Poprawiona nazwa: **`icon_avatar_[slot]_[cosmetic_id].png`**, żyjąca w `assets/ui/icons/` obok reszty ikon `system`, z `.ase` źródłem mirrorowanym w `assets/_source/icons/` (ten sam source-file discipline co §8:155) — jedna rodzina nazewnictwa dla całego projektu zamiast dwóch koegzystujących schematów.

**Accessibility/contrast-safety requirement (added 2026-07-23, design-review — ux-designer + art-director convergent finding, blocking)**: `FrameColor` i `BackgroundFill` są czystym color-only różnicowaniem (palette-token swap, brak osobnego PNG per wpis) — bez żadnego wymogu grayscale-distinguishability, w niezgodzie z `class-path-system.md`'s §UI Requirements, który wymaga dokładnie takiego sprawdzenia wszędzie gdzie color-coding jest zakazane w tym projekcie. Wymóg: (1) każdy token `FrameColor`/`BackgroundFill` musi pozostać rozróżnialny w grayscale render — ten sam acceptance criterion co art-bible §4:67 dla resource pills; (2) każda kombinacja `BackgroundFill` musi przejść kontrast-safety check przeciwko stałemu outline'owi twarzy (i przeciwko outline'owi dowolnego equipped `Accessory`) — resource-pill precedent, na który powołuje się ten GDD, nigdy nie podmienia tła za stałym, outline'owanym assetem, więc nie jest wystarczającym uzasadnieniem samo w sobie bez tego sprawdzenia. Dokładny mechanizm (dozwolona pula tokenów, min-contrast próg) odroczony do `/asset-spec`, ale wymóg jego istnienia jest zablokowany tutaj.

**Rozwiązanie napięcia "ciepły akcent"**: ciepło żyje w AGENCJI (wybór gracza, 20 ręcznie autorowanych opcji) i w już istniejącej strukturalnej odrębności kółka avatara (§3 — jedyny kształt niedzielony z pigułkami/przyciskami), nie w stylu renderowania. Żaden kosmetyk nie dostaje specjalnego traktowania glow/ruch/hierarchia-kolorów względem innego — ciepłe uczucie pochodzi z tego CO gracz wybiera, nigdy z tego JAK system renderuje wybory różnie.

📌 **Asset Spec** — po zatwierdzeniu art bible dla tej rodziny assetów, uruchom `/asset-spec system:cosmetic-persona-customization`.

## UI Requirements

Nowy ekran/panel: Cosmetic Persona screen — avatar preview + 3 sloty (`Accessory`/`FrameColor`/`BackgroundFill`), lista opcji per slot z `Locked/Muted Slot` convention (`interaction-patterns.md`). Nawigacja: prawdopodobnie piąty panel `MainNavCoordinator`-owy (wzorem `StaffPanel`, ADR-0014) LUB podekran w istniejącym miejscu (np. rozszerzenie `ClassPathPanel`) — dokładna decyzja należy do `/ux-design`, nie do tego GDD.

> **📌 UX Flag — Cosmetic Persona Customization**: Ten system ma wymagania UI. Uruchom `/ux-design` przed pisaniem epics/stories — stories referencing UI powinny cytować `design/ux/cosmetic-persona-screen.md` (lub podobną nazwę), nie ten GDD bezpośrednio.

**Unlock-signal requirement (reopened 2026-07-23, design-review — was locked as a mandatory persistent badge earlier the same session, reversed after creative-director/ux-designer adversarial finding)**: a persistent push-badge/dot on the nav entry was flagged as a pattern this project has never used anywhere else — every other pending-state cue (Locked/Muted Slot, disabled-control tooltips, etc.) is pull-based/discoverable, and a standing nag indicator sits in tension with the "precision without judgment" tone anchor (art-bible §1) and Anti-Pillar 2's no-pressure-signaling spirit. **Revised constraint**: no persistent push-badge. The Cosmetic entry point itself may surface unequipped-unlocked state only when the player is already looking at it (e.g., the nav entry's own rest-state reflects "N new" the moment it's rendered, or the screen's own entry list highlights new-since-last-visit items on open) — a one-shot, non-persistent acknowledgment is acceptable; a standing badge that persists across sessions until dismissed is not. Exact mechanism still deferred to `/ux-design`, but the constraint (pull-based only, no persistent nag) is locked here in its place.

## Acceptance Criteria

*Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**Testability note**: `CosmeticSystem` is unimplemented — spec only. All criteria below are **BLOCKING against a mocked `HistoryFlagManager.has_milestone()`** — same pattern as `prestige-checkpoint-system.md`'s and `team-staff-management.md`'s Era Reset sections.

### Unlock Detection (Core Rule 2/3, Formulas note a)

- **GIVEN** `HistoryFlagManager.has_milestone("class_path.pato_streamer.best_tier.3")` returns `true`, **WHEN** the (pato_streamer, tier 3) table entry is evaluated, **THEN** its `cosmetic_id` reports state `Unlocked`. **[Logic — BLOCKING]**
- **GIVEN** the same milestone returns `false`, **THEN** the entry reports state `Locked`. **[Logic — BLOCKING]**
- **GIVEN** three milestones for three different (path, tier) entries all flip from `false` to `true` within the same frame, **WHEN** all 20 entries are re-evaluated, **THEN** each entry's result depends only on its own `has_milestone()` call — order of evaluation doesn't change any result. **[Logic — BLOCKING]**

### Mix-and-Match Equipping (Core Rule 5, States table)

- **GIVEN** an `Accessory` unlocked via `pato_streamer` tier 2 and a `FrameColor` unlocked via `guru_celebryta` tier 4, **WHEN** the player equips both via `equip_cosmetic()`, **THEN** both apply simultaneously with no cross-path validation. **[Logic — BLOCKING]**
- **GIVEN** a `cosmetic_id` whose milestone is `false`, **WHEN** `equip_cosmetic(slot, cosmetic_id)` is called, **THEN** it returns `false`, no mutation — only `Unlocked → Equipped` is reachable, `Locked → Equipped` is not. **[Logic — BLOCKING]**
- **GIVEN** a `cosmetic_id` whose table `slot` doesn't match the `slot` parameter passed to `equip_cosmetic()`, **THEN** it returns `false`, no mutation — hard rejection, never silent reassignment to the correct slot. **[Logic — BLOCKING]**
- **GIVEN** a cosmetic is `Equipped` in a slot, **WHEN** the player equips a different `Unlocked` cosmetic valid for that slot, **THEN** the previous one transitions back to `Unlocked` (never `Locked`), exactly one cosmetic occupies the slot afterward. **[Logic — BLOCKING]**

### Era-Reset Immunity for Equipped Loadout (Edge Cases)

- **GIVEN** an equipped loadout at the moment an era-reset/burnout transition fires, **WHEN** the transition's flag-sweep completes, **THEN** all three equipped slot values are unchanged (`==` field comparison, not a serialized-bytes diff). **[Integration — BLOCKING, mocked era-transition emitter]** *(rewording 2026-07-23, qa-lead finding: "byte-for-byte" was ambiguous — this is a field-equality check on 3 StringNames, not a serialization comparison)*

### Milestone-Never-Clears Immunity (Edge Cases)

- **GIVEN** a milestone was `true` in one era, **WHEN** queried again in a later era, **THEN** it still returns `true` — regression guard against a future `CosmeticSystem`-side caching bug, not a re-test of `HistoryFlagManager` itself. **[Integration — BLOCKING]** *(qa-lead note, 2026-07-23: against today's spec — CosmeticSystem never caches, always re-reads `has_milestone()` live per Core Rule 4 — this AC is trivially true by construction; it exists as a tripwire for if/when a caching layer is ever added, not a test of current behavior. Keep it, but don't count it as meaningful coverage today.)*

### Fresh-Save Default State (Edge Cases)

- **GIVEN** a fresh save where all 20 `has_milestone()` checks return `false`, **WHEN** the content table is evaluated, **THEN** `get_unlocked_ids()` returns empty for all three slots and all 20 entries individually report state `Locked`. **[Integration — BLOCKING, mocked HistoryFlagManager]** *(reworded 2026-07-23, qa-lead finding: original phrasing ("screen initializes"/"display as Locked") implied UI rendering; this is a data-layer check, headlessly testable without the screen existing)*
- **GIVEN** the data-layer state above, **WHEN** the Cosmetic Persona screen renders it, **THEN** all 20 entries are visible using the Locked/Muted Slot convention (never hidden), all three slots show the baseline avatar. **[UI — ADVISORY, manual walkthrough]** *(split out 2026-07-23 as the UI-rendering half of the original criterion)*

### Missing-Save-Key / Corrupted-Save Default Behavior (Edge Cases)

*Mock note (added 2026-07-23, qa-lead finding): all criteria in this section require a mocked `SaveSystem` returning the stated persisted state, and the third criterion additionally requires a mocked/edited content table (an entry present at save-time but absent or slot-reassigned at load-time) — named explicitly here since the original text only stated this for the first criterion.*

- **GIVEN** a save predating this system (no equipped-loadout key), **WHEN** `CosmeticSystem` initializes, **THEN** all three slots default to unequipped/baseline, no crash. **[Integration — BLOCKING, mocked SaveSystem]**
- **GIVEN** a persisted equipped `cosmetic_id` whose milestone reads `false` on load, **WHEN** `restore_state()` runs, **THEN** the persisted value is trusted unconditionally — no re-validation against `has_milestone()` at load time. **[Integration — BLOCKING, mocked SaveSystem]** *(reclassified 2026-07-23 from Logic to Integration — same `restore_state()`×`SaveSystem` codepath as its siblings in this section, qa-lead finding)*
- **GIVEN** a persisted equipped `cosmetic_id` that does not exist anywhere in the current content table (deleted by a future content edit, typo, or manual save edit), **WHEN** `restore_state()` runs, **THEN** that slot resets to unequipped/baseline, no crash — distinct from the milestone-false case above, where the table entry still exists. **[Integration — BLOCKING, mocked SaveSystem + mocked/edited content table]** *(reclassified 2026-07-23, same reason as above)*
- **GIVEN** a persisted equipped `cosmetic_id` that still exists in the content table but whose `slot` field was reassigned by a content edit since the save was written (added 2026-07-23, systems-designer finding — third boundary case, see Edge Cases), **WHEN** `restore_state()` runs, **THEN** it re-validates the loaded value's slot against the table's current `slot` for that `cosmetic_id`; on mismatch, that slot resets to unequipped/baseline, no crash. **[Integration — BLOCKING, mocked SaveSystem + mocked content table with a reassigned slot]**

### Content-Table Integrity — Regression Guards (Core Rule 1, Anti-Pillar 2; added scope 2026-07-23)

*Classification note (added 2026-07-23, qa-lead finding): these are static content/schema validations executable via a CI content-lint script, not runtime unit tests of a formula or state machine — this project's Logic/Integration/UI/Visual/Config-Data taxonomy (`coding-standards.md`) has no dedicated "CI content-lint" bucket. Tagged `[Content-Lint — BLOCKING]` here pending a taxonomy update; treat as a required CI gate, not a `tests/unit/` suite entry.*

- **GIVEN** any combination of unlocked/equipped state, **WHEN** the content table and slot enum are validated (at load time and via CI content-lint), **THEN** exactly three customizable slots exist and no slot or table entry ever targets avatar face/expression — must remain true regardless of future content additions. **[Content-Lint — BLOCKING]** *(retagged 2026-07-23, was `[Logic — BLOCKING]`)*
- **GIVEN** the full 20-entry content table, **WHEN** it is validated via CI content-lint, **THEN** no two `cosmetic_id` entries share the same `unlock_milestone` string, and every entry's `slot` is one of the three valid enum values (`Accessory`/`FrameColor`/`BackgroundFill`) — catches a content-authoring error that would otherwise silently unlock two cosmetics together or orphan an entry. **[Content-Lint — BLOCKING]** *(new 2026-07-23, systems-designer + qa-lead convergent finding — previously no AC covered table-wide integrity, only the face-lock special case)*

### General Invariants

- **GIVEN** any sequence of `equip_cosmetic()` calls across all three slots, **THEN** at every point in time exactly one cosmetic (or baseline/none) occupies each slot — never zero-after-a-successful-equip, never two simultaneously in one slot. **[Logic — BLOCKING]** *(new 2026-07-23, qa-lead finding — previously only the single swap-in-progress scenario was covered, not the general property)*

### Unlock-Signal Requirement (UI Requirements; revised scope 2026-07-23)

- **GIVEN** at least one cosmetic is `Unlocked` but not `Equipped`, **WHEN** the player navigates to and opens the Cosmetic entry point, **THEN** that pending state is visibly surfaced (per the pull-based mechanism `/ux-design` selects). **GIVEN** no cosmetic is `Unlocked`-and-not-`Equipped`, **THEN** no pending-state indicator renders. **[UI — ADVISORY, manual walkthrough]** *(new 2026-07-23, qa-lead finding — previously the locked badge requirement had no AC at all; rewritten pull-based per the reopened UI Requirements constraint above)*
- **GIVEN** the pending-state indicator is showing, **THEN** it must never persist across app restarts/sessions once the player has viewed the Cosmetic screen at least once since the unlock occurred — regression guard against accidentally reintroducing a persistent push-badge. **[UI — ADVISORY, manual walkthrough]** *(new 2026-07-23)*

### Visual Accessibility (Visual/Audio Requirements)

- **GIVEN** each `FrameColor` and `BackgroundFill` palette token, **WHEN** rendered in a grayscale conversion, **THEN** all tokens for that slot remain mutually distinguishable — same acceptance bar as art-bible §4's resource-pill grayscale check. **[Visual/Feel — ADVISORY, screenshot + art-director sign-off]** *(new 2026-07-23, ux-designer + art-director convergent finding)*
- **GIVEN** each `BackgroundFill` token, **WHEN** composited behind the fixed deadpan face outline and any equipped `Accessory` outline, **THEN** the face/accessory outline remains legible at the minimum contrast bar used elsewhere in this project's UI (art-bible §1 "legibility is the fairness"). **[Visual/Feel — ADVISORY, screenshot + art-director sign-off]** *(new 2026-07-23, art-director finding)*

## Open Questions

- **Piąty panel `MainNavCoordinator`-owy vs subscreen w `ClassPathPanel`** — odroczone do `/ux-design`, nie rozstrzygnięte tutaj. **Design-review note (2026-07-23, ux-designer finding)**: `/ux-design` powinien dostać wskaźnik na już udokumentowane HUD-crowding ryzyko w `class-path-system.md:280` (5 istniejących pigułek zasobów + nowy chip) — piąty panel nawigacyjny to cięższy ask niż jeden chip HUD, ten sam typ ryzyka nie powinien być odkrywany od zera.
- **Layout wyboru opcji per slot nienazwany jako gap** (added 2026-07-23, ux-designer finding) — grid vs. carousel vs. lista dla do 20 opcji w 3 slotach na ekranie 9:16, touch-target sizing, nie ma nawet wzmianki jako Open Question mimo że siostrzane GDD (np. `class-path-system.md`) explicite nazywają własne UI-gapy. Odroczone do `/ux-design`, ale odnotowane tutaj jako realny, nienazwany wcześniej brak. *Owner: `/ux-design` pass.*
- **20 assetów kosmetycznych to realny content-authoring lift** na Full Vision priority — timeline nierealistyczny przed Alpha/Beta, warty uwzględnienia w planowaniu produkcji. *Owner: producer, przy planowaniu Full Vision milestone.*
- ~~**Brak notyfikacji "odblokowałeś nowy kosmetyk"**~~ — **REOPENED 2026-07-23 (design-review, reversing the same-day lock)**: poprzednia rezolucja zakładała, że jakiś persistent badge/dot MUSI istnieć. Creative-director + ux-designer adversarial finding: persistent push-badge to wzorzec, którego ten projekt nigdy nie użył (każdy inny pending-state cue jest pull-based/discoverable), w napięciu z "precision without judgment" (art-bible §1). **Nowa rezolucja**: brak persistent badge; UI Requirements teraz wymaga pull-based-only mechanizmu (patrz sekcja powyżej), dokładny mechanizm wciąż do `/ux-design`. *Owner: `/ux-design` pass, tylko dla mechanizmu — z ograniczeniem "pull-based only" jako twardym constraintem, nie tylko sugestią.*
- **Realny sufit odblokowań to dziś 10 z 20, nie 20** (zweryfikowane względem shipped code, design-review 2026-07-23) — zero kart taggowanych `ekspert_niszowy`/`biznesmen_contentu` w `card-content-database.md`, więc te dwie ścieżki nigdy nie osiągają żadnego tieru w realnej grze dopóki content nie zostanie dopisany. To content-authoring gap, nie architektoniczny — sam system działa poprawnie z 10 czy 20 wpisami bez zmian logiki. **Wzmocnione 2026-07-23 (game-designer finding, blocking dla collector-fantasy claim)**: dopóki ten gap nie zostanie zamknięty, Edge Cases' "wiem że tam coś jest" uzasadnienie jest tylko częściowo prawdziwe — zob. adnotacja przy tym Edge Case. *Owner: producer/narrative-director, przy planowaniu Full Vision milestone — patrz też istniejący Open Question o 20-assetowym lift.*
- **Ikona stylu rozszerzona na kosmetyki (art-director decision, ta sesja)** — locked kierunek, ale same 20 assetów jeszcze nieautorowane. *Owner: `/asset-spec` po zatwierdzeniu art bible dla tej rodziny.*
- **Mix-and-match a czytelność archetypu** (added 2026-07-23, game-designer finding) — nieograniczone mieszanie kosmetyków między ścieżkami (Core Rule 5) nigdy nie zostało skonfrontowane z Pillar 3's satyrycznym zamiarem czytelnej tożsamości archetypu ("widocznie jestem tym typem"). Brak zmiany reguły w tym przejściu — real, ale not identity-breaking (ten sam standard co class-path-system.md's replay-variety Open Question) — flagowane do rozważenia, nie rozstrzygnięte. *Owner: unassigned, revisit post-playtest jeśli faktycznie odczuwalne.*
- **"Ciepło przez agencję, nigdy przez hierarchię wizualną" jest asercją, nie zweryfikowanym faktem** (added 2026-07-23, game-designer finding) — rozwiązanie napięcia "ciepły akcent w zimnej estetyce" (Visual/Audio Requirements) zakłada, że całkowity brak hierarchii rarity nie spłaszczy właśnie tego ciepła, którego system ma dostarczyć. Żaden Acceptance Criterion nie testuje emocjonalnego payoffu (tylko poprawność mechaniczną) — flagowane jako założenie do zweryfikowania przy pierwszym playteście tego ekranu, nie rozstrzygnięte teraz. *Owner: unassigned, revisit post-playtest.*
