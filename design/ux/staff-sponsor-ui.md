# UX Spec: Staff/Sponsor UI

> **Status**: Complete — `/ux-review` APPROVED (2026-07-23, 0 blocking / 2 advisory, resolved)
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-23
> **Platform**: Android + Web (HTML5, CrazyGames)
> **Journey Phase(s)**: unknown — no `design/player-journey.md` yet
> **Template**: UX Spec

---

## Purpose & Player Need

Gracz przegląda 3 role (Troll/Asystent/Sponsor Manager), widzi ile ma zatrudnionych, ile kosztuje kolejny, i świadomie decyduje gdzie zainwestować Sponsory dla większego tempa (żywej gry lub offline). Bez tego ekranu cały `team-staff-management.md` (3 role, `hire_cost`, `staff_multiplier`) nie ma żadnego interfejsu — dane i logika istnieją, wybór dla gracza nie.

---

## Player Context on Arrival

Przycisk widoczny w topbarze od pierwszej sesji, dostępny zawsze podczas żywej gry — dobrowolne otwarcie, nie wymuszone przez żaden trigger (w przeciwieństwie do Wypalenia/Challenge Selection). Stan emocjonalny: strategiczna kalkulacja — "czy stać mnie, czy warto", podobne do Class Path Panel's inwestycyjnego feel, nie spokojny check-in jak Meta-Bonus Visibility (tu jest aktywna decyzja wydawania).

---

## Navigation Position

`action_screen.tscn` (główny ekran) → `StaffButton` (topbar, czwarty obok Path/Settings/Bonuses) → `StaffPanel`. Top-level, zawsze dostępny podczas żywej gry — ten sam wzorzec co `BonusesPanel` (ADR-0014). Resolver `MainNavCoordinator` już generalizuje się do N paneli bez zmian architektonicznych.

---

## Entry & Exit Points

| Entry Source | Trigger | Gracz niesie ten kontekst |
|---|---|---|
| Main screen topbar | Tap `StaffButton` | Brak specjalnego kontekstu |
| Inny panel otwarty | Tap `StaffButton` | Poprzedni panel zamyka się first (Core Rule 4) |

| Exit Destination | Trigger | Uwagi |
|---|---|---|
| Main screen | Close button | Ten sam ~100ms fade co Path/Settings/Bonuses (ADR-0014) |
| Main screen | Back-gesture (Android) / Esc (Web) | Identyczne zachowanie co Close |
| Karta decyzji | `card_presented` | Panel zamyka się natychmiast, karta ma priorytet (Core Rule 5) |

Brak nieodwracalnych wyjść — samo zatrudnienie (Interaction Map) jest odwracalne tylko przez era-reset (`team-staff-management.md` Edge Cases), nie przez zamknięcie tego panelu.

---

## Layout Specification

### Information Hierarchy

1. **Najważniejsze — 3 wiersze ról**: liczba zatrudnionych, koszt następnego, przycisk Hire.
2. **Drugie — aktualny balans Sponsorów**, żeby gracz nie musiał wychodzić sprawdzić.
3. **Widoczne, NIE ukryte — aktualny multiplier per rola jako liczba** (np. "+75% tempa Hejterów"), żeby uniknąć dokładnie tego błędu znalezionego w `ClassPathPanel` (Tier N bez liczb — Pillar 1 violation, `class-path-system.md` Open Questions).

### Layout Zones

Header (balans Sponsorów + Close) + 3 wiersze ról, ten sam wzorzec co `BonusesPanel`/`ClassPathPanel` (spójność wizualna). Każdy wiersz: ikona/nazwa + liczba zatrudnionych + aktualny multiplier + koszt następnego + przycisk Hire.

### Component Inventory

**Header:**
- `SponsorsBalanceLabel` — nieinteraktywny tekst, aktualny balans Sponsorów
- `CloseButton` — standardowy Button, `close_requested` (ADR-0014)

**3× `StaffRow`** (jeden per rola):
- `RoleIcon` — nieinteraktywny, per rola (asset spec potrzebny)
- `RoleNameLabel` — humanizowana nazwa (Troll/Asystent/Sponsor Manager)
- `StaffCountLabel` — liczba zatrudnionych
- `CurrentMultiplierLabel` — aktualny `staff_multiplier(type, n)`, wyświetlany jako procentowa delta nad baseline: `(staff_multiplier(type,n) − 1.0) × 100` (np. multiplier `1.75` → "+75%")
- `NextCostLabel` — `hire_cost(type, n)` dla następnego hire
- `HireButton` — Affordable (aktywny) / Unaffordable (disabled + `Disabled-State Tooltip`, `interaction-patterns.md`)

### ASCII Wireframe

```
┌─────────────────────────────────┐
│  Zespół                 [Close] │
│  Sponsorzy: 42                  │
├─────────────────────────────────┤
│ 😈 Troll             3 zatrudn. │
│    +75% tempa Hejterów          │
│    Koszt: 27          [ Hire ]  │
├─────────────────────────────────┤
│ 🧑‍💼 Asystent          1 zatrudn. │
│    +30% tempo offline           │
│    Koszt: 5            [ Hire ] │
├─────────────────────────────────┤
│ 📋 Sponsor Manager    0 zatrudn.│
│    +0% dochód Sponsorów         │
│    Koszt: 6             [ Hire ]│
└─────────────────────────────────┘
```

---

## States & Variants

| Stan/Wariant | Trigger | Co się zmienia |
|---|---|---|
| Default | Normalna gra, mieszane liczby | Każdy wiersz niezależnie Affordable/Unaffordable |
| Fresh-era | `staff_count[type]==0` dla wszystkich (nowa era lub pierwsza sesja) | Zwykły stan początkowy — wszystkie multipliery na baseline (1.0x/0%), koszty na `hire_cost(type,0)` — NIE specjalny stan, spójne z konwencją "zawsze pokaż realne zero" |
| Error | N/A | Czysty odczyt już zwalidowanego stanu, zero I/O które mogłoby się nie udać |
| Loading | N/A | Zero async |
| Platform variant | Android vs Web | Brak różnicy layoutu |

---

## Interaction Map

Input: Touch (Android primary) + mysz przez `emulate_touch_from_mouse` (Web/CrazyGames).

| Komponent | Akcja | Input | Natychmiastowy feedback | Skutek |
|---|---|---|---|---|
| `StaffButton` (topbar) | Tap/click | Touch/mysz | Standardowy button press | `coordination_state → PANEL_OPEN` (StaffPanel), inny panel zamyka się first |
| `CloseButton` | Tap/click | Touch/mysz | ~100ms fade zamknięcia | `close_requested` → `coordination_state → NO_OVERLAY` |
| `HireButton` (Affordable) | Tap/click | Touch/mysz | Standardowy press + natychmiastowa aktualizacja liczb | `staff_count[type]++`, Sponsory pomniejszone o `hire_cost`, `CurrentMultiplierLabel`/`NextCostLabel` przeliczają się w tej samej klatce |
| `HireButton` (Unaffordable) | Tap/click | Touch/mysz | Pokazuje `Tooltip` | Brak zmiany stanu |

---

## Events Fired

| Akcja gracza | Event | Payload |
|---|---|---|
| `HireButton` tap (Affordable) | brak analytics (brak infrastruktury, jak pozostałe spec'i) | — |
| `CloseButton`/back-gesture | brak | — |

**⚠️ Hire modyfikuje trwały stan gry**: `ResourceManager.apply_delta()` (Sponsory -`hire_cost`), `staff_count[type]++` — już w pełni zaprojektowana architektura (`team-staff-management.md`), ten ekran jest wyłącznie triggerem.

---

## Transitions & Animations

Otwarcie/zamknięcie: identyczny fade co pozostałe panele (~120-150ms/100ms, ADR-0014 konwencja). Hire: krótki `self_modulate` flash na wierszu (ten sam kanał co `FeedbackMath`'s action-channel pill flash) — natychmiastowe potwierdzenie "to się policzyło". **Reduce Motion**: fade skraca się do near-instant; flash pozostaje (już reduce-motion-bezpieczny — opacity, nie ruch).

---

## Data Requirements

| Dane | System źródłowy | Odczyt/Zapis | Uwagi |
|---|---|---|---|
| Sponsory | `ResourceManager.get_resource(&"Sponsors")` | Read | Już istnieje |
| `staff_count[type]` × 3 | Nowy Autoload `TeamStaffManagement` | Read | Zaprojektowane w `team-staff-management.md`, nie zaimplementowane |
| `staff_multiplier(type, n)` × 3 | j.w. | Read | Formula 1 |
| `hire_cost(type, n)` × 3 | j.w. | Read | Formula 2 |
| Hire | j.w. → `ResourceManager.apply_delta()` | Write | `staff_count[type]++`, Sponsory -`hire_cost` |
| `RoleNameLabel`/`RoleIcon` (3× treść) | Statyczna treść (nie system stanu gry) | Read (compile-time) | Nazwa/ikona per rola, nie zapytanie do żadnego systemu |

Wszystko już w pełni zaprojektowane w `team-staff-management.md` — zero nowej architektury potrzebnej dla tego ekranu.

---

## Accessibility

Cross-referencing `design/accessibility-requirements.md` (Tier: Basic):
- **Touch target**: `StaffButton`/`CloseButton`/`HireButton` ≥44×44dp.
- **Brak informacji tylko przez kolor**: `CurrentMultiplierLabel`/`StaffCountLabel`/`NextCostLabel` zawsze tekstowe, disabled `HireButton` to przyciemnienie + `Tooltip`, nigdy sam kolor.
- **Kontrast tekstu**: min 4.5:1.
- **Reduce Motion**: pokryte w Transitions & Animations.
- **Screen reader**: poza zakresem, zgodnie z tier Basic.

---

## Localization Considerations

`RoleNameLabel` i `CurrentMultiplierLabel` ("+75% tempa Hejterów") najdłuższe, layout-critical przy 40% ekspansji tłumaczenia. Ta sama flaga co pozostałe spec'i: język UI gry to angielski, nie polski — etykiety w tym dokumencie są roboczym językiem projektowym.

---

## Acceptance Criteria

- [ ] Panel otwiera się w ≤1 klatce od tapnięcia StaffButton
- [ ] GIVEN StaffButton tapnięty gdy inny panel otwarty, THEN poprzedni panel zamyka się w tej samej klatce przed pojawieniem się StaffPanel (Core Rule 4)
- [ ] GIVEN `staff_count[type]==0` dla wszystkich ról (fresh era), THEN wszystkie 3 wiersze widoczne z realnymi wartościami bazowymi (multiplier 1.0x/0%, koszt `hire_cost(type,0)`) — żaden wiersz nie jest ukryty
- [ ] KAŻDY wiersz zawsze pokazuje aktualny multiplier jako liczbę tekstową — nigdy tylko "zatrudniony"/"aktywny" bez wartości (Pillar 1, unika błędu znalezionego w ClassPathPanel)
- [ ] GIVEN Sponsory ≥ `hire_cost(type,n)`, WHEN HireButton tapnięty, THEN `staff_count[type]++`, Sponsory pomniejszone, `NextCostLabel`/`CurrentMultiplierLabel` przeliczają się w tej samej klatce
- [ ] GIVEN Sponsory < `hire_cost(type,n)`, THEN HireButton disabled, tap pokazuje tooltip, brak zmiany stanu
- [ ] Wszystkie interaktywne elementy mają touch target ≥44×44dp
- [ ] Close button, back-gesture (Android) i Esc (Web) prowadzą do identycznego zachowania zamknięcia

---

## Open Questions

- **`RoleIcon` × 3 niezaprojektowane** — potrzebny asset spec, styl outline+flat fill bez highlightu per art-bible (2026-07-11 lock). *Owner: `/asset-spec system:staff-sponsor-ui`.*
- **ADR-0014 potrzebuje kolejnej rewizji dla 4. panelu** (8→10 entry points) — ta sama generalizacja bez zmiany architektonicznej co przy dodaniu `BonusesPanel`. *Owner: rewizja ADR-0014, przed implementacją tego ekranu.*
- **Język UI (Polish→English audit)** — ta sama flaga co pozostałe spec'i.
- **Brak `design/player-journey.md`** — ten spec projektowano bez mapy podróży gracza.
- **Osiągalność hire tier 7-8 w jednej erze** — już śledzone w `team-staff-management.md` Open Questions, nie duplikowane tu.
