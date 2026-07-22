# UX Spec: Challenge Selection Screen

> **Status**: Complete — `/ux-review` NEEDS REVISION → fixed same session (2026-07-22, 1 blocking finding: missing zero-grant fallback for MetaBonusGrantedLabel — resolved)
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-22
> **Platform**: Android + Web (HTML5, CrazyGames)
> **Journey Phase(s)**: unknown — no `design/player-journey.md` yet
> **Template**: UX Spec

---

## Purpose & Player Need

Gracz trafia tu zaraz po Wypaleniu z dwoma potrzebami naraz: (1) zamknięcie wątku — "co właściwie dostałem/am za tę erę" (era-summary recap, most do Meta-Bonus Visibility bez wymuszania osobnego otwarcia panelu), (2) świadomy wybór — "czy chcę utrudnić sobie tę erę dla większego zysku" (0..`CHALLENGE_MAX_ACTIVE` Challenges). Bez tego ekranu cały `ChallengeSystem` ("gracz świadomie utrudnia sobie życie dla obietnicy większej wypłaty", quick-spec Overview) nie ma żadnego interfejsu — dane i logika istnieją, wybór dla gracza nie.

---

## Player Context on Arrival

Natychmiast po `era_transitioned` (zaraz po Choice A na karcie Wypalenie), zanim jakakolwiek inna logika era-startu wznowi się (Core Rule 1, quick-spec). Stan emocjonalny: przejście z ciężkości karty Wypalenie do trybu strategicznego planowania — ulga/ciekawość ("co dostałem") mieszająca się z kalkulacją ("czy warto utrudnić"). Gra wysyła gracza tutaj (nie dobrowolne przybycie), ale sam wybór wewnątrz jest w pełni dobrowolny — 0 wybranych to kompletna, ważna decyzja.

---

## Navigation Position

`action_screen.tscn` → (po `era_transitioned`) → `change_scene_to_file(challenge_selection.tscn)` → potwierdzenie → `change_scene_to_file(action_screen.tscn)` powrót do żywej gry. To NIE jest scena osiągalna przez normalną nawigację — wyłącznie automatyczny trigger z `era_transitioned`, żadnej alternatywnej ścieżki wejścia, żadnego sposobu żeby gracz wrócił tu poza tym jednym momentem (Rule 1.5 quick-specu: "ekran pokazywany tylko na starcie ery").

**Realna luka architektoniczna znaleziona przy projektowaniu**: to nowe przejście międzyscenowe (`action_screen.tscn` → `challenge_selection.tscn` → z powrotem) wywołane zdarzeniem w grze (`era_transitioned`), nie tylko przy boot. `ADR-0003` pokrywa wyłącznie sekwencję boot→offline_report→main; `MainNavCoordinator`/ADR-0014 pokrywa tylko koordynację paneli WEWNĄTRZ `action_screen.tscn`. Żaden istniejący ADR nie pokrywa scene-swap wywołanego runtime eventem w środku żywej sesji — patrz Open Questions.

---

## Entry & Exit Points

| Entry Source | Trigger | Gracz niesie ten kontekst |
|---|---|---|
| `action_screen.tscn`, dowolny stan | `PrestigeSystem.era_transitioned` sygnał, natychmiast po Wypalenie Choice A | Nowa era już aktywna (reset zastosowany); żaden kontekst UI z poprzedniej sceny nie jest przenoszony |

| Exit Destination | Trigger | Uwagi |
|---|---|---|
| `action_screen.tscn` (żywa gra wznawia się) | Confirm button | Jedyne wyjście — działa nawet przy 0 wybranych challenge'ach |

**Brak innych wyjść**: żaden dismiss, tap-anywhere, ani commit bez Confirm. Back-gesture (Android)/Esc (Web): **ignorowane**, tym samym precedensem co Offline Report Screen (osobna scena, własna obsługa `NOTIFICATION_WM_GO_BACK_REQUEST` — poza zakresem `MainNavCoordinator`, który koordynuje tylko `action_screen.tscn`). Ten sam "ekran tylko na starcie ery, brak alternatywnej ścieżki" hard-gate co karta Wypalenie (quick-spec Rule 1.5).

---

## Layout Specification

### Information Hierarchy

1. **Najważniejsze — wybór 5 challenge'ów**: nazwa/flavor/modifier/`meta_bonus_multiplier` na każdym, stan zaznaczenia, przycisk Confirm.
2. **Drugie — era-summary recap**: co właśnie dostałeś/aś (typ + liczba meta-bonusu z Wypalenia), nowy numer ery.
3. **Discoverable — żywy podgląd łącznego `combined_meta_multiplier`**, aktualizowany przy każdym zaznaczeniu/odznaczeniu (Pillar 1 — widzisz wynik PRZED confirm).
4. **Discoverable — licznik `CHALLENGE_MAX_ACTIVE`** (X z 3 wybranych).

### Layout Zones

Header (era-summary recap: "Era {N} rozpoczęta. Zyskałeś/aś trwały bonus: +X% [typ]") + scrollowalna lista 5 challenge cards (selectable, checkbox-style toggle) + sticky footer z żywym `combined_meta_multiplier` i licznikiem `X/CHALLENGE_MAX_ACTIVE` + przycisk Confirm. Zgodne z już zatwierdzonym Purpose & Player Need (oba cele na jednym ekranie, bez wymuszania osobnego panelu).

### Component Inventory

**Header:**
- `EraSummaryLabel` — "Era {N} rozpoczęta"
- `MetaBonusGrantedLabel` — dokładna kwota właśnie przyznanego bonusu, LUB "Brak bonusu tej ery" gdy poprzednia era zakończyła się bez aktywnej ścieżki (No Bonus Granted state, States & Variants). **Nowa potrzeba API**: `PrestigeSystem.era_transitioned` dziś nie ma payloadu (żadnych argumentów, `architecture.md` v2) — potrzebne albo dodanie payloadu do sygnału, albo queryable pole "ostatni grant" na `PrestigeSystem`, w tym jawna reprezentacja "nic nie przyznano" (nie tylko `0.0`, żeby odróżnić od realnego zerowego wyniku formuły). Flagowane w Open Questions.

**5× `ChallengeCard`** (selectable, checkbox-style):
- `ChallengeNameLabel`, `ChallengeFlavorText` — z katalogu (`assets/data/challenges.json`, quick-spec)
- `ChallengeModifierLabel` — np. "Nagraj vloga: 0.3× Reach"
- `ChallengeMetaBonusMultLabel` — np. "×2.0 meta-bonus"
- `SelectionToggle` — stan zaznaczony/niezaznaczony

**Sticky Footer:**
- `CombinedMultiplierLabel` — żywy `combined_meta_multiplier`, przelicza się przy każdej zmianie zaznaczenia
- `SelectionCountLabel` — "X/`CHALLENGE_MAX_ACTIVE`"
- `ConfirmButton`

### ASCII Wireframe

```
┌─────────────────────────────────┐
│  Era 4 rozpoczęta                │
│  Zyskałeś: +10.7% Stały zasięg  │
├─────────────────────────────────┤
│ ☑ Influencer bez duszy          │
│   Nagraj vloga: 0.3× Reach      │
│   ×2.0 meta-bonus                │
├─────────────────────────────────┤
│ ☐ Drama queen bez granic        │
│   Zrób dramę: 2.0× Cringe        │
│   ×2.5 meta-bonus                │
├─────────────────────────────────┤
│ ☐ Przeproś, ale nie za bardzo   │
│   Przeproś: 0.3× Cringe recovery│
│   ×1.8 meta-bonus                │
├─────────────────────────────────┤
│ ☑ Bez tłumu nie ma show          │
│   Wszystkie akcje: 0.5× Reach   │
│   ×3.0 meta-bonus                │
├─────────────────────────────────┤
│ ☐ Wypalony, ale core             │
│   Przeproś: 0.6× Morale          │
│   ×2.0 meta-bonus                │
├─────────────────────────────────┤
│ Łączny mnożnik: ×6.0    2/3      │
│         [ CONFIRM ]              │
└─────────────────────────────────┘
```

---

## States & Variants

| Stan/Wariant | Trigger | Co się zmienia |
|---|---|---|
| Default | 0 wybranych | `combined_meta_multiplier = 1.0`, wszystkie 5 toggle aktywne |
| At-cap | 3/3 wybrane (`CHALLENGE_MAX_ACTIVE`) | Pozostałe niezaznaczone toggle disabled + `Disabled-State Tooltip` (reużyty pattern z Wypalenie Card Modal); próba zaznaczenia 4. odrzucona (quick-spec AC) |
| No Bonus Granted | Poprzednia era zakończyła się Wypaleniem bez aktywnej ścieżki (ten sam przypadek co `wypalenie-card-modal.md`'s No Active Path state, jeden krok później w sekwencji) | `MetaBonusGrantedLabel` pokazuje "Brak bonusu tej ery" zamiast procentu — nigdy pusty/zepsuty label, nigdy `0%` sugerujące że jakiś (choćby zerowy) grant istniał |
| Error | N/A | Czysty odczyt katalogu + lokalny stan wyboru, zero I/O które mogłoby się nie udać |
| Loading | N/A | Katalog `challenges.json` ładowany przy starcie `ChallengeSystem`, nie przy otwarciu tego ekranu |
| Platform variant | Android vs Web | Brak różnicy layoutu |

---

## Interaction Map

Input: Touch (Android primary) + mysz przez `emulate_touch_from_mouse` (Web/CrazyGames).

| Komponent | Akcja | Input | Natychmiastowy feedback | Skutek |
|---|---|---|---|---|
| `ChallengeCard` toggle (aktywny) | Tap/click | Touch/mysz | Standardowy toggle press state | Zaznacza/odznacza; `CombinedMultiplierLabel` i `SelectionCountLabel` przeliczają się natychmiast |
| `ChallengeCard` toggle (disabled, at-cap) | Tap/click | Touch/mysz | Pokazuje `Tooltip` | Brak zmiany stanu — czysto informacyjne |
| `ConfirmButton` | Tap/click | Touch/mysz | Standardowy button press | Zawsze aktywny (nawet przy 0 wybranych) — commituje selekcję, `change_scene_to_file(action_screen.tscn)` |

---

## Events Fired

| Akcja gracza | Event | Payload |
|---|---|---|
| Toggle `ChallengeCard` | brak analytics (brak infrastruktury, jak pozostałe spec'i) | — |
| `ConfirmButton` tap | brak analytics | — |

**⚠️ Confirm modyfikuje trwały stan gry**: zapisuje wybrane challenge'e jako era-local flagi w `HistoryFlagManager` (`"challenge_active_" + challenge_id`, quick-spec Rule 3) — to już w pełni zaprojektowana architektura (`ChallengeSystem`), ten ekran jest wyłącznie triggerem. Flagowane jawnie, tym samym duchem co Wypalenie Card Modal.

---

## Transitions & Animations

Wejście: fade-in ~150-200ms po załadowaniu sceny (ten sam zakres co Full-Screen Blocking Modal pattern, mimo że to osobna scena, nie modal). Wyjście: fade-out, potem `change_scene_to_file(action_screen.tscn)` — ten sam wzorzec `showing→hidden` co Offline Report Screen. `CombinedMultiplierLabel`: natychmiastowa aktualizacja przy toggle, bez animacji-opóźnienia (Pillar 1 — czytelność liczby przed efektownością). **Reduce Motion**: ta sama konwencja co reszta projektu, `SettingsSystem.reduce_motion`.

---

## Data Requirements

| Dane | System źródłowy | Odczyt/Zapis | Uwagi |
|---|---|---|---|
| Katalog 5 challenge'ów | `ChallengeSystem.get_challenge_data(id)` | Read | Już istnieje |
| `CHALLENGE_MAX_ACTIVE` | Tuning knob const | Read | Już istnieje |
| Żywy `combined_meta_multiplier` (przed Confirm) | **Lokalna matematyka UI**, nie wywołanie do `ChallengeSystem` | Read (local compute) | Iloczyn `meta_bonus_multiplier` zaznaczonych kart z już wczytanego katalogu — nic nie jest jeszcze zapisane do systemu przed Confirm, więc nie ma czego odpytywać. Nie nowe API. |
| `MetaBonusGrantedLabel` (kwota z Wypalenia) | `PrestigeSystem` — **NOWA potrzeba** (patrz Component Inventory) | Read | Dziedziczy flagowaną potrzebę: `era_transitioned` payload lub queryable "ostatni grant"; musi rozróżniać "nic nie przyznano" (No Bonus Granted state) od realnego zera |
| Confirm → `select_challenges(challenge_ids)` | `ChallengeSystem` | Write | Już w pełni zaprojektowane — zapisuje era-local flagi (Events Fired) |

Jedyny nowy wymóg architektoniczny: ten sam co w `wypalenie-card-modal.md` (kwota ostatniego grantu) — nie duplikowany tu jako osobny problem, to ten sam brakujący kawałek API czytany w dwóch miejscach.

---

## Accessibility

Cross-referencing `design/accessibility-requirements.md` (Tier: Basic):
- **Touch target**: `ChallengeCard` toggle i `ConfirmButton` ≥44×44dp.
- **Brak informacji tylko przez kolor**: disabled toggle (at-cap) to przyciemnienie + `Tooltip` tekst, nigdy sam kolor.
- **Kontrast tekstu**: min 4.5:1.
- **Reduce Motion**: pokryte w Transitions & Animations.
- **Brak feedbacku tylko-przez-ruch dla informacji krytycznej**: `CombinedMultiplierLabel` i `MetaBonusGrantedLabel` zawsze tekstowe, nigdy komunikowane wyłącznie animacją.
- **Screen reader**: poza zakresem, zgodnie z tier Basic.

---

## Localization Considerations

`ChallengeFlavorText` (satyryczne opisy, pełne zdania, np. "Wiesz że to nie wychodzi dobrze...") to najdłuższy element — wieloliniowy z założenia, mniej layout-critical niż jednowierszowe etykiety, ale nadal potrzebuje sensownego maksimum przy 40% ekspansji, żeby karta nie rosła nieproporcjonalnie. `ChallengeNameLabel` ma ten sam problem co inne krótkie etykiety w projekcie (HIGH PRIORITY).

Ta sama flaga co pozostałe spec'i: język UI gry to angielski, nie polski.

---

## Acceptance Criteria

- [ ] Scena pojawia się natychmiast po `era_transitioned`, przed jakąkolwiek inną logiką era-startu (Rule 1, quick-spec)
- [ ] GIVEN 0 wybranych challenge'ów, WHEN Confirm tapnięty, THEN `combined_meta_multiplier = 1.0` i przejście do `action_screen.tscn` działa identycznie jak przy niezerowej selekcji
- [ ] GIVEN dwie karty zaznaczone (multiplier 2.0 i 2.5), THEN `CombinedMultiplierLabel` pokazuje `5.0` natychmiast po drugim zaznaczeniu, bez opóźnienia
- [ ] GIVEN 3/3 już zaznaczone, WHEN gracz próbuje zaznaczyć 4., THEN próba odrzucona, tooltip wyjaśnia dlaczego (quick-spec AC)
- [ ] Back-gesture (Android)/Esc (Web) podczas tego ekranu: zawsze ignorowane — jedyne wyjście to Confirm
- [ ] `MetaBonusGrantedLabel` pokazuje dokładną liczbę zgodną z tym, co Wypalenie card wcześniej podglądał (ta sama wartość, nie przybliżenie)
- [ ] GIVEN poprzednia era zakończyła się bez aktywnej ścieżki, WHEN ten ekran się pokazuje, THEN `MetaBonusGrantedLabel` pokazuje "Brak bonusu tej ery" — nigdy pusty label ani mylące `0%`
- [ ] Wszystkie interaktywne elementy (toggle, Confirm) mają touch target ≥44×44dp
- [ ] Tekst kontrastu ≥4.5:1

---

## Open Questions

- **Kwota ostatniego grantu — nowe API potrzebne.** `PrestigeSystem.era_transitioned` nie ma dziś payloadu. Ten sam brakujący kawałek co w `wypalenie-card-modal.md` Open Questions — nie duplikowany tu jako osobny problem. *Owner: `/architecture-decision` lub amendment do ADR-0012, przed implementacją obu ekranów.*
- **Scene-swap wywołany runtime eventem — luka w pokryciu ADR.** Patrz Navigation Position: ani ADR-0003 (tylko boot sequence), ani ADR-0014 (tylko koordynacja paneli wewnątrz `action_screen.tscn`) nie pokrywa przejścia `action_screen.tscn` → `challenge_selection.tscn` → z powrotem wywołanego `era_transitioned`. *Owner: nowy `/architecture-decision` przed implementacją tego ekranu — prawdopodobnie mały ADR, wzorem ADR-0009's precedent dla podobnego przypadku (Offline Report Screen).*
- **Dokładne wartości fade** (120-150ms/100ms zakres) — kierunek ustalony, liczby do feel-testu.
- **Język UI (Polish→English audit)** — ta sama flaga co pozostałe spec'i.
- **Brak `design/player-journey.md`** — ten spec projektowano bez mapy podróży gracza.
