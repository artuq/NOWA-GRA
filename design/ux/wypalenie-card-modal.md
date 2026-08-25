# UX Spec: Wypalenie Card Modal

> **Status**: Complete — `/ux-review` NEEDS REVISION → fixed same session (2026-07-22, 1 blocking finding: missing locked "no active path" warning state — resolved)
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-22
> **Platform**: Android + Web (HTML5, CrazyGames)
> **Journey Phase(s)**: unknown — no `design/player-journey.md` yet
> **Template**: UX Spec

---

## Purpose & Player Need

Gracz staje przed jedynym naprawdę ciężkim wyborem w całej grze — Wypalenie karta wymusza decyzję: (A) Zaakceptować (stracić wszystko bieżące, zyskać coś trwałego) albo (B) Odłożyć raz (zapłacić Morale, kupić czas). Bez tego ekranu cały system prestiżu traci swoją stawkę — DDR-0001 #5 wprost wymaga, żeby to był narracyjny checkpoint z prawdziwymi konsekwencjami, nie miękka, pomijalna przeszkoda. Gracz nie trafia tu dobrowolnie — gra go tu wysyła (wymuszone, po ostrzegawczym countdownie), ale zawsze wybiera świadomie (Pillar 2 — nic nie jest mu zrobione bez zgody).

---

## Player Context on Arrival

Karta pojawia się wymuszenie po `BURNOUT_THRESHOLD` (domyślnie 300s) utrzymanego Cringe=100, poprzedzona widocznym countdownem ostrzegawczym od `BURNOUT_WARNING_THRESHOLD` (180s) — w ramach jednej sesji gracz miał czas to poczuć nadciągające. Bezpośrednio przed: zwykła żywa gra, prawdopodobnie tapanie akcji przy suficie Cringe. Stan emocjonalny: napięcie narastające z countdownu, moment przybycia = dramatyczny szczyt (przeciwieństwo spokojnego check-inu panelu Bonusów). **Ważne odstępstwo dla pierwszego napotkania**: zgodnie z otwartym pytaniem w `prestige-checkpoint-system.md` (dodanym 2026-07-22), gra nigdy nie zapowiada tej mechaniki PRZED pierwszą sesją, w której się pojawia — pierwszy gracz może dotrzeć tu zaskoczony/niezorientowany, nie tylko napięty, jeśli nie zauważył countdownu na czas. Ten spec projektuje samą kartę zakładając, że gracz WIDZIAŁ countdown (w ramach sesji to prawda), ale nie zakłada, że rozumie z góry CO ta karta oznacza — copy karty musi samodzielnie wyjaśnić stawkę, nie polegać na wcześniejszej wiedzy.

---

## Navigation Position

Nie jest to "miejsce", do którego gracz nawiguje — to wymuszony interrupt na warstwie `CardScreen` (topmost), pojawiający się nad którymkolwiek stanem głównego ekranu (`no_overlay` lub `panel_open` — zamyka otwarty panel, Core Rule 5 Main Nav GDD). Nie może wystąpić podczas Raportu Offline (timer Cringe nie inkrementuje offline, Core Rule 1 quick-specu) ani podczas boot. Jedno globalne miejsce wejścia: `BurnoutSystem`'s wymuszona iniekcja, zero alternatywnych ścieżek.

---

## Entry & Exit Points

| Entry Source | Trigger | Gracz niesie ten kontekst |
|---|---|---|
| Dowolny stan głównego ekranu (`no_overlay`/`panel_open`) | `BurnoutSystem` timer osiąga `BURNOUT_THRESHOLD` → `inject_priority_card()` | Otwarty panel (Path/Settings/Bonuses) zamyka się natychmiast, bez animacji, przed pojawieniem karty (Core Rule 5 Main Nav GDD) |

| Exit Destination | Trigger | Uwagi |
|---|---|---|
| Główny ekran (era trwa dalej) | Swipe-commit → Choice B (Odłóż) | Tylko jeśli `has_deferred_this_era() == false` |
| Główny ekran (nowa era, reset) | Swipe-commit → Choice A (Zaakceptuj) | Zawsze dostępne |

**Brak innych wyjść**: żaden dismiss, żaden tap-anywhere, back-gesture ignorowany (Main Nav Rule 6, druga linia — karta ma bezwzględny priorytet). Swipe w kierunku Defer, gdy `has_deferred_this_era() == true`: zawsze bounce-back niezależnie od przekroczenia progu 30% — twarda blokada, nie miękkie zniechęcenie, sygnalizowana greyed label + tooltip PRZED próbą gestu.

---

## Layout Specification

### Information Hierarchy

1. **Najważniejsze — dwa wybory i ich konsekwencje**: Choice A (stracisz wszystko bieżące, zyskasz TRWAŁY podgląd liczby) vs Choice B (zapłać Morale, kup czas), Defer greyed+tooltip jeśli już użyte tej ery.
2. **Drugie — wizualna emfaza że to NIE jest zwykła karta**: różne chrome od normalnego Card UI, sygnalizuje wagę momentu zanim gracz przeczyta tekst (Purpose & Player Need — pierwszy gracz może nie wiedzieć co to znaczy, wizualna waga musi nieść część komunikatu).
3. **Discoverable — dokładna liczba meta-bonusu** (podgląd przed commitem, Pillar 1) i koszt Morale za Defer.
4. **Discoverable — flavor text/copy** tłumaczący stawkę dla gracza, który nie zna tej mechaniki z góry (Section B finding).

### Layout Zones

Identyczny mechanizm gestu co zwykłe karty Card UI (mięśniowa pamięć gracza już ustalona) — emfaza przez skalę karty i intensywność scrimu (ciemniejszy niż standardowy Full-Screen Blocking Modal), NIE przez kolor (anti-pillar: no-valence coding, ta sama zasada co zwykłe karty). Etykiety obu wyborów po lewej/prawej stronie karty (zgodnie z istniejącym Card UI layoutem), z liczbą/kosztem pod każdą etykietą — meta-bonus podgląd pod Choice A, koszt Morale pod Choice B (lub tooltip zamiast kosztu, jeśli greyed).

### Component Inventory

- `Scrim` — nieinteraktywny, ciemniejszy/intensywniejszy niż standardowy Full-Screen Blocking Modal, bez valence-koloru
- `CardBody` — większa skala niż zwykła karta Card UI, reużywa `CardSwipeMath` (ADR-0008)
- `HeadlineText` — nieinteraktywny, copy tłumaczący stawkę dla gracza bez wcześniejszej wiedzy o mechanice (Section B finding)
- `ChoiceALabel` + `MetaBonusPreviewLabel` — dynamiczna liczba, ten sam format co `BonusValueLabel` (`meta-bonus-visibility.md`); zastąpiony ostrzeżeniem tekstowym w stanie No Active Path (States & Variants) — locked wymóg GDD, nie opcjonalny
- `ChoiceBLabel` + `MoraleCostLabel` — statyczny koszt (`BURNOUT_DEFER_MORALE_COST`), LUB greyed treatment + `Tooltip` gdy `has_deferred_this_era() == true`

**Nowy pattern — Tooltip**: użyty już w 3 miejscach projektu (Queue full — `action-system.md`, Class Path disabled Invest — `class-path-system.md`, teraz Choice B greyed) ale nigdy niesformalizowany w `interaction-patterns.md`. Flagowany do dodania w Section 5.

### ASCII Wireframe

```
┌─────────────────────────────────┐
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│ ← scrim, ciemniejszy niż standard
│▓  ┌───────────────────────────┐▓│
│▓  │        WYPALENIE          │▓│
│▓  │                           │▓│
│▓  │  "Twoje imperium właśnie  │▓│
│▓  │   uderzyło w sufit..."    │▓│
│▓  │                           │▓│
│▓  │  ODŁÓŻ          ZAAKCEPTUJ│▓│
│▓  │  -50 Morale     +10.7%    │▓│
│▓  │  (raz na erę)   Stały     │▓│
│▓  │                 zasięg    │▓│
│▓  │      ← swipe →            │▓│
│▓  └───────────────────────────┘▓│
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
└─────────────────────────────────┘
```

---

## States & Variants

| Stan/Wariant | Trigger | Co się zmienia |
|---|---|---|
| Default | `has_deferred_this_era() == false` | Choice B w pełni dostępny, koszt Morale widoczny |
| Deferred-already | `has_deferred_this_era() == true` | Choice B greyed, tooltip zamiast kosztu, swipe w tę stronę zawsze bounce-back (Entry & Exit Points) |
| No Active Path | `ClassPathSystem.get_active_path()` puste (niezafiliowany LUB ambiguous per Class Path F5) w momencie pokazania karty | `MetaBonusPreviewLabel` zastąpiony jawnym ostrzeżeniem ("Brak aktywnej ścieżki — to Wypalenie nie przyzna trwałego bonusu") zamiast liczby. **Locked wymóg GDD** (`prestige-checkpoint-system.md`, linia 254, `/design-review` 2026-07-13 — "MUST surface this before the player confirms", nie opcjonalne). Reset wciąż następuje normalnie przy Choice A — brak aktywnej ścieżki nigdy nie blokuje resetu, tylko usuwa nagrodę. |
| Error | N/A | Podgląd meta-bonusu liczony synchronicznie PRZED pokazaniem karty (Data Requirements) — nic nie może się nie udać w trakcie wyświetlania |
| Loading | N/A | Zero async — karta pojawia się dopiero gdy wszystkie dane są już policzone |
| Platform variant | Android vs Web | Brak różnicy layoutu |

---

## Interaction Map

Input: Touch (Android primary) + mysz przez `emulate_touch_from_mouse` (Web/CrazyGames).

| Komponent | Akcja | Input | Natychmiastowy feedback | Skutek |
|---|---|---|---|---|
| `CardBody` | Swipe lewo (Defer) / prawo (Accept) | Touch/mysz drag | Rotacja proporcjonalna do dystansu, ten sam `CardSwipeMath` co zwykłe karty (ADR-0008) | ≥30% szerokości ekranu + release → commit; <30% → bounce-back |
| `CardBody` (Defer strona, gdy greyed) | Swipe lewo | Touch/mysz drag | Zawsze bounce-back, niezależnie od dystansu | No-op — twarda blokada (Entry & Exit Points) |
| Greyed `ChoiceBLabel` | Tap | Touch/mysz | Pokazuje `Tooltip` z wyjaśnieniem | Brak zmiany stanu — czysto informacyjne |

Brak innych interaktywnych elementów — zero dismiss/tap-anywhere/back-gesture (już pokryte w Entry & Exit Points).

---

## Events Fired

| Akcja gracza | Event | Payload |
|---|---|---|
| Swipe-commit Choice A | brak nowego analytics eventu (brak infrastruktury, jak `meta-bonus-visibility.md`) | — |
| Swipe-commit Choice B | brak | — |

**⚠️ Obie akcje modyfikują trwały stan gry** — Choice A uruchamia całą maszynerię era-transition (`PrestigeSystem.on_burnout_accepted()`: grant meta-bonusu, reset 5 zasobów, `ClassPathSystem.reset_era_state()`, `era_count += 1`), Choice B modyfikuje Morale i ustawia `_deferred_this_era`. To już w pełni zaprojektowana architektura (ADR-0012/ADR-0013) — ten ekran jest wyłącznie triggerem przez `DecisionCardSystem.resolve_choice()`, nie właścicielem żadnej z tych mutacji. Flagowane tu jawnie, bo to najwyższa-stawkowa para akcji w całej grze.

---

## Transitions & Animations

Wejście: ten sam fade+scrim mechanizm co Full-Screen Blocking Modal (pattern), ale na wolniejszym końcu istniejącego zakresu (~250-300ms zamiast standardowych 150-200ms) — cięższy, dramatyczniejszy wjazd, nie nowy typ animacji. Wyjście: standardowy resolution beat karty (fly-off w kierunku commitu, ten sam co zwykłe Card UI karty) + `FeedbackMath` shake/flash na `ResourceHud`, ten sam kanał co normalna resolucja karty. **Reduce Motion**: ta sama konwencja co reszta projektu — skraca się do near-instant, `SettingsSystem.reduce_motion`.

---

## Data Requirements

| Dane | System źródłowy | Odczyt/Zapis | Uwagi |
|---|---|---|---|
| `has_deferred_this_era()` | `PrestigeSystem` | Read | Już istnieje |
| `BURNOUT_DEFER_MORALE_COST` | Tuning knob const | Read | Już istnieje |
| Podgląd meta-bonusu (F1 formuła), bez commitu | `PrestigeSystem.compute_next_grant(path_id, tier)` (ADR-0017) | Read (pure, no side effects) | Wołane jako `compute_next_grant(ClassPathSystem.get_active_path(), ClassPathSystem.get_tier(...))` — ta sama funkcja co realny grant, gwarancja identycznych liczb |
| `get_active_path()` zwraca puste (null handling) | `ClassPathSystem` | Read | Gdy puste: preview pomija liczbę całkowicie, pokazuje ostrzeżenie zamiast niej (No Active Path state) — nie `0` ani placeholder liczbowy, żeby nie sugerować fałszywie że jakaś (choćby zerowa) nagroda istnieje |
| Copy karty (HeadlineText, flavor) | Statyczna treść (CardContentDatabase, `BURNOUT_CARD_ID` entry) | Read | Treść, nie stan gry |
| Choice A/B commit → cała era-transition machinery | `DecisionCardSystem.resolve_choice()` → `BurnoutSystem` → `PrestigeSystem` | Write | Już w pełni zaprojektowane (ADR-0012/0013) — patrz Events Fired |

Jedyny nowy wymóg architektoniczny na tym ekranie: preview-only wariant F1 formuły. Wszystko inne już istnieje.

---

## Accessibility

Cross-referencing `design/accessibility-requirements.md` (Tier: Basic):
- **Touch target**: tooltip-trigger na greyed `ChoiceBLabel` ≥44×44dp.
- **Brak informacji tylko przez kolor**: greyed Choice B to wizualne przyciemnienie + `Tooltip` tekst — nigdy sam kolor jako jedyny sygnał niedostępności.
- **Kontrast tekstu**: min 4.5:1.
- **Reduce Motion**: pokryte w Transitions & Animations.
- **Brak feedbacku tylko-przez-ruch dla informacji krytycznej** (Commitment 4): dokładna liczba meta-bonusu i koszt Morale są zawsze tekstowe (`MetaBonusPreviewLabel`/`MoraleCostLabel`), nigdy komunikowane wyłącznie animacją — najwyższa stawka w grze zasługuje na tę dyscyplinę najbardziej ze wszystkich ekranów.
- **Screen reader**: poza zakresem, zgodnie z tier Basic.

---

## Localization Considerations

`HeadlineText` (flavor, wieloliniowy) i `ChoiceALabel`/`ChoiceBLabel` (krótkie słowa-czasowniki: "Zaakceptuj"/"Odłóż") oba layout-critical przy 40% ekspansji tłumaczenia — słowa-czasowniki szczególnie ryzykowne, bo krótkie angielskie słowa ("Accept"/"Defer") często rozrastają się nieproporcjonalnie w innych językach. HIGH PRIORITY dla obu.

Ta sama flaga co `meta-bonus-visibility.md`: język UI gry to angielski, nie polski — etykiety w tym dokumencie są roboczym językiem projektowym.

---

## Acceptance Criteria

- [ ] Karta pojawia się dopiero gdy meta-bonus preview jest już policzony — brak stanu "karta widoczna, liczba jeszcze się ładuje"
- [ ] GIVEN panel otwarty (Path/Settings/Bonuses) w momencie triggera, THEN panel zamyka się natychmiast, bez animacji, przed pojawieniem karty (Core Rule 5)
- [ ] Back-gesture (Android)/Esc (Web) podczas karty: zawsze ignorowane, karta pozostaje widoczna — zero wyjątków
- [ ] GIVEN `has_deferred_this_era() == false`, THEN podgląd meta-bonusu pod Choice A pokazuje dokładną liczbę zgodną z F1 formułą dla aktywnej ścieżki klasy
- [ ] GIVEN `has_deferred_this_era() == true`, WHEN gracz swipe'uje w kierunku Defer (nawet ≥30% progu), THEN zawsze bounce-back — commit nigdy nie następuje
- [ ] GIVEN Choice B greyed, WHEN gracz tapnie tę stronę karty, THEN tooltip pokazuje wyjaśnienie ("już raz odłożyłeś/aś tej ery")
- [ ] Wszystkie interaktywne elementy (tooltip-trigger) mają touch target ≥44×44dp
- [ ] Tekst kontrastu (HeadlineText, labels, liczby) ≥4.5:1
- [ ] GIVEN `ClassPathSystem.get_active_path()` puste (niezafiliowany lub ambiguous), WHEN karta Wypalenie się pokazuje, THEN ostrzeżenie "brak aktywnej ścieżki, brak trwałego bonusu" widoczne PRZED jakimkolwiek swipe'em — nigdy cichy zero-reward burnout (locked GDD requirement, `prestige-checkpoint-system.md` linia 254)

---

## Open Questions

- ~~**Preview meta-bonusu — nowa architektura potrzebna.**~~ — **RESOLVED 2026-07-22**: `ADR-0017` written — `PrestigeSystem.compute_next_grant(path_id, tier) -> Dictionary{granted, type, amount}`, pure, called by this card as `compute_next_grant(ClassPathSystem.get_active_path(), ClassPathSystem.get_tier(...))` before any swipe commits. Same function `on_burnout_accepted()` uses for the real grant — guaranteed identical numbers.
- **Dokładne wartości wizualnej intensywności** (ciemność scrimu, dokładny czas wejścia w zakresie 250-300ms) — kierunek ustalony, liczby do feel-testu. *Owner: po pierwszym playteście.*
- **Niezapowiedziana mechanika dla pierwszego gracza** — ten spec projektuje samą kartę zakładając widziany countdown w sesji, ale nie rozwiązuje szerszego pytania już śledzonego w `prestige-checkpoint-system.md` Open Questions (dodane 2026-07-22): gra nigdy nie zapowiada mechaniki era-reset przed pierwszym napotkaniem. *Owner: ten sam co tamto pytanie, nie duplikowany tu.*
- **Język UI (Polish→English audit)** — ta sama flaga co `meta-bonus-visibility.md`, część już śledzonego długu.
- **Brak `design/player-journey.md`** — ten spec projektowano bez mapy podróży gracza.
- **Alternatywny trigger oparty na liczbie kart, nie czasie rzeczywistym** (dodane 2026-07-22, feedback zewnętrznego designera przez usera) — zobacz `final-burnout-2026-07-01.md` Open Questions. Jeśli przyjęte, wpłynie na Player Context on Arrival tego spec'a (dziś zakłada odczuwalny countdown czasu rzeczywistego).
- **Stalling minigame ("swipe hejterskich komentarzy") przed decyzją** (dodane 2026-07-22, ten sam feedback) — koliduje z Core Rule 3 tego ekranu ("no dismiss without choosing") i natychmiastową-stawką framingiem (DDR-0001 #5). Zobacz `final-burnout-2026-07-01.md` Open Questions dla pełnego omówienia napięcia.
