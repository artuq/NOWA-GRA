# UX Spec: Burnout Warning HUD Indicator

> **Status**: Complete — `/ux-review` APPROVED (2026-07-22, 0 blocking / 1 advisory, resolved)
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-22
> **Platform**: Android + Web (HTML5, CrazyGames)
> **Journey Phase(s)**: unknown — no `design/player-journey.md` yet
> **Template**: UX Spec

---

## Purpose & Player Need

Gracz widzi nadciągające Wypalenie zanim uderzy — ambientowy sygnał w tle zwykłej gry, budujący napięcie bez przerywania. Bez tego wskaźnika karta Wypalenie byłaby czystym zaskoczeniem, nie zapowiedzianą nieuchronnością — dokładnie przeciwieństwo Player Fantasy z `prestige-checkpoint-system.md` ("narastający, widoczny countdown ostrzegawczy buduje napięcie w tle"). Gracz nie musi na niego reagować aktywnie — to peryferyjna świadomość, nie wymuszona uwaga.

---

## Player Context on Arrival

Pojawia się automatycznie po `BURNOUT_WARNING_THRESHOLD` (180s) utrzymanego Cringe=100 — gracz w trakcie zwykłej żywej gry, prawdopodobnie tapiąc akcje generujące Cringe. Stan emocjonalny: rosnący niepokój budowany przez ~2 minuty przed właściwym triggerem (300s). Gra go wysyła (niedobrowolne pojawienie), ale wyłącznie ambientowe — zero wymuszonej interakcji, gracz może je zignorować i kontynuować grę.

---

## Navigation Position

Żyje w Resource HUD zone działającej Action UI (`action_screen.tscn`), jako czwarty element obok już istniejących `ResourceHud`/`ActionGrid`/`RunningActionOverlay`. Node zawsze obecny w drzewie, `visible=false` domyślnie — ten sam wzorzec co `RunningActionOverlay` (toggle, nie instancjonowanie na żądanie). Logicznie niezależny od `coordination_state` (Main Nav GDD) — nie jest gated przez to, czy panel jest otwarty; jeśli panel wizualnie zasłania HUD, to efekt z-orderu/layoutu, nie decyzja tego spec'a.

---

## Entry & Exit Points

| Entry Source | Trigger | Gracz niesie ten kontekst |
|---|---|---|
| Ambient, dowolny stan żywej gry | `BurnoutSystem.burnout_warning_changed(true, seconds_remaining)` | Brak — pojawia się bez interakcji gracza |

| Exit Destination | Trigger | Uwagi |
|---|---|---|
| Ukrycie (Cringe spadł) | `burnout_warning_changed(false, 0.0)` | Cringe spadł poniżej 100 przed właściwym triggerem |
| Ukrycie (karta się pojawia) | `DecisionCardSystem.card_presented` (dowolna karta, nie tylko Wypalenie) | **Realny finding, zweryfikowany w `burnout_system.gd`**: `_try_inject_burnout_card()` resetuje `_cringe_sustained_seconds = 0.0` cicho przy iniekcji karty — `burnout_warning_changed(false, 0.0)` NIE jest emitowany w tej ścieżce (tylko przy spadku Cringe). Bez tego drugiego listenera wskaźnik zostałby "zaklinowany" pokazując ostatnią znaną wartość (~0s) w nieskończoność. |

---

## Layout Specification

### Information Hierarchy

1. **Najważniejsze — `seconds_remaining` jako wizualny countdown** (pasek/liczba), sygnalizujący "ile czasu zostało".
2. **Drugie — identyfikacja że to konkretnie ostrzeżenie Wypalenia**, nie inny system (ikona/label odróżniająca od reszty HUD).

### Layout Zones

Mały shrinking bar w tym samym rzędzie co pigułki zasobów (Resource HUD) + liczba sekund. Ten sam wzorzec co "Per-Frame Progress Bar" (neutralny track, zawsze sparowany z tekstem, nigdy sam pasek). Ikona identyfikująca powiązana z Wypaleniem — **NIE** ikona-trójkąt-ostrzegawczy (kształt sam w sobie niósłby valence, sprzeczne z art-bible §1 "nigdy nie przyjmuje rejestru dobry/zły").

### Component Inventory

- `WarningIcon` — nieinteraktywny, identity icon powiązana z Wypaleniem (nie trójkąt-ostrzegawczy)
- `CountdownBar` — kurczy się, odwrotność "Per-Frame Progress Bar": `fill_ratio = clamp(seconds_remaining / (BURNOUT_THRESHOLD − BURNOUT_WARNING_THRESHOLD), 0, 1)` — okno 120s (300−180) od momentu pierwszej emisji `burnout_warning_changed(true, ...)` do triggera
- `SecondsRemainingLabel` — zawsze tekstowy, sparowany z paskiem (nigdy pasek sam)

### ASCII Wireframe

```
┌──────────────────────────────────────────────┐
│ 🎥Reach:3.9M 😬Cringe:100 👿Haters:8.6K ...   │ ← Resource HUD row (istniejące)
├──────────────────────────────────────────────┤
│ ⚡ ▓▓▓▓▓░░░░░░░░░░░░░░░░  47s                 │ ← nowy: Burnout Warning
└──────────────────────────────────────────────┘
```

---

## States & Variants

| Stan/Wariant | Trigger | Co się zmienia |
|---|---|---|
| Hidden | Domyślny, poza oknem ostrzeżenia | `visible = false`, zero zajętej przestrzeni wizualnej (nie muted-slot, po prostu ukryte) |
| Active | `burnout_warning_changed(true, ...)` | `visible = true`, `CountdownBar`/`SecondsRemainingLabel` aktualizują się co klatkę |
| Error | N/A | Czysty odbiornik sygnału, zero I/O |
| Loading | N/A | Zero async |
| Platform variant | Android vs Web | Brak różnicy layoutu |

Oba źródła przejścia Active→Hidden już pokryte w Entry & Exit Points (spadek Cringe LUB pojawienie się karty).

---

## Interaction Map

Brak interakcji — element w pełni nieinteraktywny (ambient), zgodnie z Purpose & Player Need ("peryferyjna świadomość, nie wymuszona uwaga"). Zero touch targetów, zero tap handlerów. Input methods (Touch/mysz-emulate) nie mają tu zastosowania — nic do zmapowania.

---

## Events Fired

Brak — element nie ma żadnych akcji gracza do udokumentowania (Interaction Map). Nie modyfikuje żadnego stanu gry — czysty odbiornik sygnału.

---

## Transitions & Animations

Pojawienie: subtelny fade-in (~150-200ms), zgodny z ambientowym, nie-przerywającym charakterem (Purpose). Zniknięcie: równie subtelny fade-out, identyczny dla obu źródeł (Cringe spadł LUB karta się pojawiła) — spójność niezależnie od przyczyny. `CountdownBar`: kurczenie się co klatkę, bez osobnej animacji-tłumienia (surowa wartość, jak Per-Frame Progress Bar). **Reduce Motion**: fade skraca się do near-instant, `SettingsSystem.reduce_motion`.

---

## Data Requirements

| Dane | System źródłowy | Odczyt/Zapis | Uwagi |
|---|---|---|---|
| `active`, `seconds_remaining` | `BurnoutSystem.burnout_warning_changed` (signal) | Read | Już istnieje |
| Hide-on-card trigger | `DecisionCardSystem.card_presented` (signal) | Read | Już istnieje — patrz Entry & Exit Points finding |
| `BURNOUT_THRESHOLD`, `BURNOUT_WARNING_THRESHOLD` | `BurnoutSystem` consts | Read | Już istnieją, do obliczenia `fill_ratio` |

Zero nowego API — jedyny nowy wymóg to podłączenie DRUGIEGO listenera (`card_presented`) obok już istniejącego sygnału, po stronie implementacji UI, nie architektury.

---

## Accessibility

Cross-referencing `design/accessibility-requirements.md` (Tier: Basic):
- **Touch target**: N/A — element w pełni nieinteraktywny.
- **Brak informacji tylko przez kolor/ruch**: `SecondsRemainingLabel` zawsze tekstowy obok `CountdownBar`, nigdy sam pasek jako jedyny sygnał.
- **Kontrast tekstu**: min 4.5:1.
- **Reduce Motion**: pokryte w Transitions & Animations.
- **Screen reader**: poza zakresem, zgodnie z tier Basic.

---

## Localization Considerations

Jedyny tekst to `SecondsRemainingLabel` ("47s") — brak długich etykiet, brak realnego ryzyka layout-critical przy 40% ekspansji. Ta sama flaga języka UI co pozostałe spec'i (dla spójności, choć tu praktycznie bez znaczenia).

---

## Acceptance Criteria

- [ ] GIVEN `_cringe_sustained_seconds` osiąga `BURNOUT_WARNING_THRESHOLD` (180s), THEN wskaźnik staje się widoczny w tej samej klatce co sygnał
- [ ] GIVEN Cringe spada poniżej 100 podczas okna ostrzegawczego, THEN wskaźnik znika (fade-out) w reakcji na `burnout_warning_changed(false, 0.0)`
- [ ] GIVEN `DecisionCardSystem.card_presented` fires (dowolna karta) podczas okna ostrzegawczego, THEN wskaźnik znika — nawet bez jawnej emisji `burnout_warning_changed(false)` (kluczowy finding, Entry & Exit Points)
- [ ] `CountdownBar`'s `fill_ratio` poprawnie liczony jako `seconds_remaining / (BURNOUT_THRESHOLD − BURNOUT_WARNING_THRESHOLD)`, clamped [0,1]
- [ ] Tekst kontrastu (`SecondsRemainingLabel`) ≥4.5:1
- [ ] GIVEN `SettingsSystem.reduce_motion == true`, THEN fade pojawienia/zniknięcia skraca się do near-instant

---

## Open Questions

- **`WarningIcon` niezaprojektowana** — potrzebny asset spec, styl outline+flat fill bez highlightu per art-bible (2026-07-11 lock), bez trójkąta-ostrzegawczego (kształt=valence). *Owner: `/asset-spec system:burnout-warning-hud-indicator`.*
- **Dokładne wartości fade** — kierunek ustalony, liczby do feel-testu.
- **To jest PIERWSZY widoczny sygnał mechaniki dla pierwszego gracza** — ten sam śledzony problem co w `prestige-checkpoint-system.md` Open Questions (niezapowiedziana mechanika era-reset). Ten wskaźnik jest technicznie miejscem, gdzie gracz PIERWSZY raz coś zauważa — ale bez wcześniejszego kontekstu, "co to znaczy" wciąż nie jest jasne z samego paska. *Owner: ten sam co tamto pytanie, nie duplikowany tu.*
- **Język UI (Polish→English audit)** — ta sama flaga co pozostałe spec'i.
- **Brak `design/player-journey.md`** — ten spec projektowano bez mapy podróży gracza.
