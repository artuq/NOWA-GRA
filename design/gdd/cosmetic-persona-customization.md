# Cosmetic Persona Customization

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-07-23
> **Implements Pillar**: Brak bezpośredniego mapowania na Pillar 1-4 (czysta ekspresja tożsamości, nie mechanika rdzenia) — wspiera pośrednio Pillar 2 (decyzje mają pamięć: kosmetyki są widocznym, permanentnym śladem historii ścieżek klasy, równolegle do META_BONUS) i Pillar 3 (satyra: kosmetyki jako komentarz do "budowania marki osobistej" influencera, nigdy jako power creep).

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
5. **Equipped loadout to nowy, mały persystowany stan** — który konkretny `cosmetic_id` jest aktualnie założony per slot (3 pola). Niezależne od aktywnej ścieżki w danej erze (mix-and-match już zatwierdzone) — equipped `Accessory` może pochodzić z zupełnie innej ścieżki niż equipped `FrameColor`. Publiczne API: `equip_cosmetic(slot: StringName, cosmetic_id: StringName) -> bool` (zwraca `false`, brak mutacji, jeśli `cosmetic_id` jest `Locked` LUB jego `slot` w tabeli nie zgadza się z parametrem `slot` — slot-mismatch to twarde odrzucenie, nie ciche dopasowanie) i `get_unlocked_ids() -> Array[StringName]` (do renderowania listy odblokowanych opcji per slot).
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
- **Fresh save (0 odblokowań)**: wszystkie 20 opcji widoczne jako zablokowane (Locked/Muted Slot convention, `interaction-patterns.md`), nigdy ukryte — buduje kolekcjonerską fantazję ("wiem że tam coś jest, jeszcze tego nie mam").
- **Brak klucza equipped-loadout w save**: domyślnie baseline (zero założonych kosmetyków), ten sam missing-key-default wzorzec co każdy inny peer Autoload w projekcie.
- **Persystowany equipped `cosmetic_id`, którego milestone przy wczytaniu czyta `false`** (corrupted/ręcznie edytowany save, lub przyszłe usunięcie treści z tabeli) — `restore_state()` NIGDY nie re-waliduje przeciw `has_milestone()`; persystowana wartość jest zaufana bezwarunkowo, tak jak reszta save-state w tym projekcie. Praktycznie niemożliwe w normalnej grze (milestone'y nigdy się nie czyszczą), ale jawnie rozstrzygnięte, nie pozostawione niezdefiniowane.

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
- `FrameColor` (5 wpisów) jako palette-token swap na obrysie chipa, nie 5 osobnych PNG — data-driven, ten sam wzorzec co kolorowanie pigułek zasobów.
- `Accessory`/`BackgroundFill` (15 wpisów) jako statyczne płaskie PNG overlaye; żadna sylwetka akcesorium nie może przekroczyć footprintu chipa (większe ≠ lepsze, Anti-Pillar 2).
- Zero wbudowanego ruchu na jakimkolwiek asset kosmetycznym — ruch pozostaje wyłączną domeną systemu juice.
- Nazewnictwo: `char_avatar_[slot]_[cosmetic_id].png`.

**Rozwiązanie napięcia "ciepły akcent"**: ciepło żyje w AGENCJI (wybór gracza, 20 ręcznie autorowanych opcji) i w już istniejącej strukturalnej odrębności kółka avatara (§3 — jedyny kształt niedzielony z pigułkami/przyciskami), nie w stylu renderowania. Żaden kosmetyk nie dostaje specjalnego traktowania glow/ruch/hierarchia-kolorów względem innego — ciepłe uczucie pochodzi z tego CO gracz wybiera, nigdy z tego JAK system renderuje wybory różnie.

📌 **Asset Spec** — po zatwierdzeniu art bible dla tej rodziny assetów, uruchom `/asset-spec system:cosmetic-persona-customization`.

## UI Requirements

Nowy ekran/panel: Cosmetic Persona screen — avatar preview + 3 sloty (`Accessory`/`FrameColor`/`BackgroundFill`), lista opcji per slot z `Locked/Muted Slot` convention (`interaction-patterns.md`). Nawigacja: prawdopodobnie piąty panel `MainNavCoordinator`-owy (wzorem `StaffPanel`, ADR-0014) LUB podekran w istniejącym miejscu (np. rozszerzenie `ClassPathPanel`) — dokładna decyzja należy do `/ux-design`, nie do tego GDD.

> **📌 UX Flag — Cosmetic Persona Customization**: Ten system ma wymagania UI. Uruchom `/ux-design` przed pisaniem epics/stories — stories referencing UI powinny cytować `design/ux/cosmetic-persona-screen.md` (lub podobną nazwę), nie ten GDD bezpośrednio.

## Acceptance Criteria

*Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**Testability note**: `CosmeticSystem` is unimplemented — spec only. All criteria below are **BLOCKING against a mocked `HistoryFlagManager.has_milestone()`** — same pattern as `prestige-checkpoint-system.md`'s and `team-staff-management.md`'s Era Reset sections.

### Unlock Detection (Core Rule 2/3, Formulas note a)

- **GIVEN** `HistoryFlagManager.has_milestone("class_path.pato_streamer.best_tier.3")` returns `true`, **WHEN** the (pato_streamer, tier 3) table entry is evaluated, **THEN** its `cosmetic_id` reports state `Unlocked`. **[Logic — BLOCKING]**
- **GIVEN** the same milestone returns `false`, **THEN** the entry reports state `Locked`. **[Logic — BLOCKING]**
- **GIVEN** three milestones for three different (path, tier) entries all flip from `false` to `true` within the same frame, **WHEN** all 20 entries are re-evaluated, **THEN** each entry's result depends only on its own `has_milestone()` call — order of evaluation doesn't change any result. **[Logic — BLOCKING]**

### Mix-and-Match Equipping (Core Rule 5, States table)

- **GIVEN** an `Accessory` unlocked via `pato_streamer` tier 2 and a `FrameColor` unlocked via `guru_celebryta` tier 4, **WHEN** the player equips both via `equip_cosmetic()`, **THEN** both apply simultaneously with no cross-path validation.
- **GIVEN** a `cosmetic_id` whose milestone is `false`, **WHEN** `equip_cosmetic(slot, cosmetic_id)` is called, **THEN** it returns `false`, no mutation — only `Unlocked → Equipped` is reachable, `Locked → Equipped` is not. **[Logic — BLOCKING]**
- **GIVEN** a `cosmetic_id` whose table `slot` doesn't match the `slot` parameter passed to `equip_cosmetic()`, **THEN** it returns `false`, no mutation — hard rejection, never silent reassignment to the correct slot. **[Logic — BLOCKING]**
- **GIVEN** a cosmetic is `Equipped` in a slot, **WHEN** the player equips a different `Unlocked` cosmetic valid for that slot, **THEN** the previous one transitions back to `Unlocked` (never `Locked`), exactly one cosmetic occupies the slot afterward. **[Logic — BLOCKING]**

### Era-Reset Immunity for Equipped Loadout (Edge Cases)

- **GIVEN** an equipped loadout at the moment an era-reset/burnout transition fires, **WHEN** the transition's flag-sweep completes, **THEN** all three equipped slots are byte-for-byte unchanged. **[Integration — BLOCKING, mocked era-transition emitter]**

### Milestone-Never-Clears Immunity (Edge Cases)

- **GIVEN** a milestone was `true` in one era, **WHEN** queried again in a later era, **THEN** it still returns `true` — regression guard against a future `CosmeticSystem`-side caching bug, not a re-test of `HistoryFlagManager` itself. **[Integration — BLOCKING]**

### Fresh-Save Default State (Edge Cases)

- **GIVEN** a fresh save where all 20 `has_milestone()` checks return `false`, **WHEN** the cosmetic screen initializes, **THEN** all 20 entries display as `Locked` (never hidden), all three slots show baseline. **[Integration — BLOCKING, mocked HistoryFlagManager]**

### Missing-Save-Key / Corrupted-Save Default Behavior (Edge Cases)

- **GIVEN** a save predating this system (no equipped-loadout key), **WHEN** `CosmeticSystem` initializes, **THEN** all three slots default to unequipped/baseline, no crash. **[Integration — BLOCKING, mocked SaveSystem]**
- **GIVEN** a persisted equipped `cosmetic_id` whose milestone reads `false` on load, **WHEN** `restore_state()` runs, **THEN** the persisted value is trusted unconditionally — no re-validation against `has_milestone()` at load time. **[Logic — BLOCKING]**

### Face/Expression Lock — Regression Guard (Core Rule 1, Anti-Pillar 2)

- **GIVEN** any combination of unlocked/equipped state, **THEN** exactly three customizable slots exist and no slot or table entry ever targets avatar face/expression — must remain true regardless of future content additions. **[Logic — BLOCKING]**

## Open Questions

- **Piąty panel `MainNavCoordinator`-owy vs subscreen w `ClassPathPanel`** — odroczone do `/ux-design`, nie rozstrzygnięte tutaj.
- **20 assetów kosmetycznych to realny content-authoring lift** na Full Vision priority — timeline nierealistyczny przed Alpha/Beta, warty uwzględnienia w planowaniu produkcji. *Owner: producer, przy planowaniu Full Vision milestone.*
- **Brak notyfikacji "odblokowałeś nowy kosmetyk"** — czy gracz w ogóle się dowie bez wizyty na ekranie Cosmetic Persona? Nie krytyczne (Full Vision, opcjonalna treść, nie mechanika), ale warte rozważenia przy `/ux-design`. *Owner: `/ux-design` pass.*
- **Ikona stylu rozszerzona na kosmetyki (art-director decision, ta sesja)** — locked kierunek, ale same 20 assetów jeszcze nieautorowane. *Owner: `/asset-spec` po zatwierdzeniu art bible dla tej rodziny.*
