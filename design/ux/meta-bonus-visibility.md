# UX Spec: Meta-Bonus Visibility

> **Status**: Complete — `/ux-review` APPROVED (2026-07-22, 0 blocking / 2 advisory, both resolved)
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-22
> **Platform**: Android + Web (HTML5, CrazyGames)
> **Journey Phase(s)**: unknown — no `design/player-journey.md` yet
> **Template**: UX Spec

---

## Purpose & Player Need

Gracz otwiera panel Bonusów dobrowolnie (trzeci przycisk w topbarze, obok Path/Settings), żeby sprawdzić, co z jego dotychczasowej gry przetrwa na zawsze — jedyny widok w grze, który odpowiada na pytanie "co faktycznie zbudowałem, nie licząc tego co stracę przy następnym Wypaleniu". Bez tego ekranu Core Rule 5 ("META_BONUS-y są trwałe od momentu przyznania... jedyny stan w całej grze, który przeżywa każdy reset") jest prawdą wyłącznie w kodzie — gracz nie ma żadnego sposobu jej zweryfikować, więc centralna fantazja tego systemu (Pillar 2 doprowadzony do strukturalnego wniosku: decyzje mają trwałą pamięć) pozostaje niewidoczna. Dostępny zawsze, nie tylko po burnout — dobrowolny check-in, nie wymuszony beat.

---

## Player Context on Arrival

Przycisk widoczny w topbarze od pierwszej sesji (jak Path/Settings), ale przed pierwszym zaakceptowanym Wypaleniem panel pokazuje same zera — pierwsze realne otwarcie z sensowną treścią to zaraz po pierwszym Choice A, kiedy gracz chce zobaczyć czy liczba faktycznie wylądowała (najsilniejszy moment weryfikacji "payout, not failure"). Stan emocjonalny: ciekawość/duma przy sprawdzaniu, nie stres — to przeciwieństwo napięcia karty Wypalenie. Zawsze dobrowolny, nigdy wymuszony przez grę.

---

## Navigation Position

`action_screen.tscn` (główny ekran) → `BonusesButton` (topbar, trzeci obok Path/Settings) → `BonusesPanel`. Top-level, zawsze dostępny — nie context-dependent, nie gated żadnym stanem gry (nawet przy 0 eras panel się otwiera, tylko pokazuje zera). Jedna droga wejścia, brak alternatywnych ścieżek.

---

## Entry & Exit Points

| Entry Source | Trigger | Gracz niesie ten kontekst |
|---|---|---|
| Main screen topbar | Tap `BonusesButton` | Brak specjalnego kontekstu — zawsze ten sam widok |
| Class Path/Settings panel | Tap `BonusesButton` gdy inny panel otwarty | Poprzedni panel zamyka się first (Core Rule 4, "co najwyżej jeden panel") |

| Exit Destination | Trigger | Uwagi |
|---|---|---|
| Main screen | Close button | Ten sam ~100ms fade jak Path/Settings (ADR-0014 wzorzec) |
| Main screen | Back-gesture (Android/Web) / Esc (Web) | Identyczne zachowanie co Close (Main Nav GDD parity rule) |
| Card decyzji | `card_presented` | Panel zamyka się natychmiast, karta ma priorytet (Core Rule 5) |

Brak nieodwracalnych wyjść — panel jest wyłącznie do odczytu (żadnych zmian stanu), więc nic nie ginie przy żadnym z powyższych.

---

## Layout Specification

### Information Hierarchy

1. **Najważniejsze — 4 trwałe wartości same w sobie**: `META_REACH_MULT`, `META_SPONSOR_MULT`, `META_HATERS_RESIST`, `META_SPONSOR_FLOOR`, każda humanizowana (nie surowa nazwa enuma) — to jest cały punkt ekranu, "to przetrwało".
2. **Drugie — postęp do capu per typ**: wizualny wskaźnik jak blisko `META_BONUS_MAX[type]`, żeby "trwały postęp" czuł się jak długoterminowy cel, nie tylko liczba.
3. **Discoverable — `era_count`**: kontekst ("X er ukończonych"), nie sam punkt ekranu.
4. **Discoverable — mapowanie typ→ścieżka klasy**: skąd wziął się dany bonus (np. `META_REACH_MULT` ↔ `pato_streamer`), dla czytelności nazw.

### Layout Zones

Pionowa lista, 4 wiersze — jeden wiersz per typ bonusu. Header na górze (`era_count` + Close top-right, wzorem `ClassPathPanel`/`SettingsScreen`). Każdy wiersz: nazwa humanizowana + aktualna wartość + progress bar do capu. Powtarza wizualną gramatykę już istniejącego `ClassPathPanel` (spójność zamiast nowego wzorca, art-bible "near-zero decoration, każdy element load-bearing") zamiast wprowadzać nowy komponent typu dashboard-card.

### Component Inventory

**Header:**
- `EraCountLabel` — nieinteraktywny tekst, "Era {N} ukończona/-ych"
- `CloseButton` — standardowy Button, ten sam wzorzec co `ClassPathPanel`/`SettingsScreen` (emituje `close_requested`, ADR-0014)

**4× wiersz bonusu (`BonusRow`, jeden per typ):**
- `BonusIcon` — nieinteraktywny, ikona powiązana ze ścieżką klasy pochodzenia (asset spec potrzebny)
- `BonusLabel` — humanizowana nazwa (np. "Stały zasięg" dla `META_REACH_MULT`)
- `BonusValueLabel` — aktualna wartość, formatowana per typ: procent dla 3 typów multiplikatorów/redukcji, płaska liczba "Sponsorzy" dla `META_SPONSOR_FLOOR`
- `BonusProgressBar` — pasek postępu do `META_BONUS_MAX[type]`. **Nowy pattern**, różni się od istniejącego "Per-Frame Progress Bar" (event-driven, przelicza się tylko przy grant, nie co klatkę) — flagowany do dodania do `interaction-patterns.md` w Section 5.

### ASCII Wireframe

```
┌─────────────────────────────────┐
│  Trwałe Bonusy          [Close] │
│  Era 3 ukończona                │
├─────────────────────────────────┤
│ 🎥  Stały zasięg          +10.7%│
│     ▓▓▓▓▓░░░░░░░░░░░ 21%        │
├─────────────────────────────────┤
│ ⭐  Stały sponsoring       +4.3%│
│     ▓▓░░░░░░░░░░░░░░ 8%         │
├─────────────────────────────────┤
│ 🛡️  Odporność na hejt      +1.5%│
│     ▓░░░░░░░░░░░░░░░ 5%         │
├─────────────────────────────────┤
│ 💰  Minimum sponsorów      3.0  │
│     ▓░░░░░░░░░░░░░░░ 6%         │
└─────────────────────────────────┘
```

---

## States & Variants

| Stan/Wariant | Trigger | Co się zmienia |
|---|---|---|
| Default (progres częściowy) | Normalny stan po ≥1 burnout | Jak wireframe — realne wartości, paski częściowo wypełnione |
| Empty (0 er) | `era_count == 0`, wszystkie 4 typy `0.0` | Wszystkie 4 wiersze WIDOCZNE (nie ukryte — nic tu nie jest zablokowane/gated), wartości "0%"/"0.0", puste paski — zwykły stan początkowy, nie stan błędu |
| Capped (maxed) | `META_BONUS_total[type] == META_BONUS_MAX[type]` dla danego typu | Pasek pełny + wyraźnie inny wizualnie (np. wypełniony kolor zamiast neutralnego) — sygnalizuje "ten typ osiągnął sufit", nie przypadkowo blisko 100% |
| Error | N/A | Brak — panel to czysty odczyt już zwalidowanego stanu z pamięci (`PrestigeSystem`), zero wywołań sieciowych/zapisu, nic tu nie może się nie udać |
| Loading | N/A | Brak — dane już w pamięci Autoloadu przy otwarciu panelu, zero async fetch |
| Platform variant | Android vs Web | Brak wizualnej różnicy w layoucie — jedyna różnica to dodatkowy Esc-to-close na Web (już pokryte w Entry/Exit Points, nie layout) |

---

## Interaction Map

Input: Touch (Android primary) + mysz przez `emulate_touch_from_mouse` (Web/CrazyGames).

| Komponent | Akcja | Input | Natychmiastowy feedback | Skutek |
|---|---|---|---|---|
| `BonusesButton` (topbar) | Tap/click | Touch/mysz | Brak specjalnego — standardowy button press state | `coordination_state → PANEL_OPEN` (BonusesPanel), inny otwarty panel zamyka się first (Core Rule 4) |
| `CloseButton` (w panelu) | Tap/click | Touch/mysz | ~100ms fade zamknięcia (ADR-0014 wzorzec) | Emituje `close_requested` → `coordination_state → NO_OVERLAY` |
| `BonusRow` (którykolwiek z 4) | — | — | Brak interakcji — czysto do odczytu. Tap na wiersz to no-op, nie nawiguje nigdzie (nie ma "szczegółów" do rozwinięcia — cała treść już widoczna) | — |
| Back-gesture (Android) / Esc (Web) | System/klawisz | — | Identyczny fade co Close | Identyczne jak Close (Main Nav GDD parity rule) |

---

## Events Fired

| Akcja gracza | Event | Payload |
|---|---|---|
| `BonusesButton` tap | brak | — (brak infrastruktury analytics w projekcie; kandydat na `bonuses_panel_opened` gdyby telemetry kiedyś powstało — nie teraz) |
| `CloseButton` tap | brak | — |
| Back-gesture/Esc | brak | — |

Żadna akcja na tym ekranie nie modyfikuje trwałego stanu gry (save data, ekonomia, progres) — panel jest w 100% odczytem, zero zapisu. Nic tu nie wymaga uwagi zespołu architektury.

---

## Transitions & Animations

Otwarcie/zamknięcie identyczne jak Class Path/Settings (Main Nav GDD konwencja) — fade ~120-150ms ease-out (otwarcie), ~100ms ease-in (zamknięcie), tylko opacity, bez slide/scale. **Reduce Motion**: skraca się do near-instant, ta sama konwencja co inne panele (`SettingsSystem.reduce_motion`).

**Stan-zmiana — "świeży grant" highlight** (specyficzny dla tego ekranu): jeśli panel otwierany jest po raz pierwszy odkąd dany typ bonusu otrzymał nowy grant (od ostatniego zamknięcia panelu lub od startu sesji), ten wiersz dostaje subtelny, jednorazowy puls podświetlenia tła (opacity, nie ruch — bezpieczne pod Reduce Motion bez dodatkowej gałęzi) — wzmacnia moment "czy to wylądowało" z Purpose & Player Need. Dokładne wartości do feel-testu, ale kierunek: opacity-only, nie scale/slide, spójnie z resztą tego ekranu.

---

## Data Requirements

| Dane | System źródłowy | Odczyt/Zapis | Uwagi |
|---|---|---|---|
| `META_BONUS_total[type]` × 4 | `PrestigeSystem.get_meta_bonus_total(type)` | Read | Już istnieje, gotowe do użycia |
| `META_BONUS_MAX[type]` × 4 | `PrestigeFormulas.META_BONUS_MAX[type]` (stateless const) | Read | Już publiczny const, brak nowego API |
| `era_count` | `PrestigeSystem.get_era_count()` | Read | Już istnieje |
| Mapowanie typ→ścieżka klasy (ikony/etykiety) | Statyczna tabela lokalna w skrypcie UI | Read (compile-time) | Nie wymaga zapytania do systemu — to treść, nie stan gry |
| "Świeży grant" detekcja (highlight) | Lokalny cache poprzednich wartości w skrypcie panelu, porównywany przy każdym otwarciu | Read-only, UI-side bookkeeping | Nie wymaga nowego API na `PrestigeSystem` — panel sam pamięta ostatnio widziane wartości, diff robi lokalnie |

Brak zapisu do jakiegokolwiek systemu — cały ekran to odczyt. Nic tu nie wymaga eskalacji do architektury.

---

## Accessibility

Cross-referencing `design/accessibility-requirements.md` (Tier: Basic):
- **Touch target**: `BonusesButton`/`CloseButton` ≥44×44dp — dziedziczone z istniejącego wzorca (Commitment 1).
- **Brak informacji tylko przez kolor**: `BonusProgressBar` zawsze paruje się z `BonusValueLabel` (tekst), nigdy sam kolor paska nie niesie znaczenia. Stan "Capped" (Section D) ma też tekstowy/ikoniczny wskaźnik "MAX", nie tylko inny kolor paska.
- **Kontrast tekstu**: min 4.5:1, ten sam standard co reszta projektu (Commitment 3).
- **Reduce Motion**: pokryte w Transitions & Animations — fade i "świeży grant" highlight oba reduce-motion-safe.
- **Screen reader**: poza zakresem, zgodnie z "Explicitly Deferred" w `accessibility-requirements.md`.

---

## Localization Considerations

Najdłuższy element to `BonusLabel` (humanizowana nazwa bonusu) — musi zmieścić się w jednej linii obok ikony i `BonusValueLabel` bez zawijania (layout-critical, HIGH PRIORITY przy 40% text expansion). Budżet znaków: **≤18 znaków EN / ≤13 znaków po doliczeniu 40% marginesu ekspansji** (`/ux-review` finding, 2026-07-22 — wartość szacunkowa do potwierdzenia przy ustaleniu szerokości wiersza w Visual Design, ale liczba, nie tylko jakościowy opis). `EraCountLabel`'s "Era {N} ukończona/-ych" wymaga obsługi pluralizacji (polski: 3 formy 1/2-4/5+; angielski: 2 formy).

**Ważniejsza kwestia**: gra ma ustaloną decyzję, że język UI to **angielski**, nie polski — wszystkie etykiety w tym dokumencie ("Stały zasięg" itd.) są roboczym językiem projektowym, nie finalną treścią UI. Wymaga przejścia przez audyt tłumaczenia razem z resztą już zidentyfikowanego polskiego contentu w projekcie (istniejący dług, nie nowy dla tego ekranu).

---

## Acceptance Criteria

- [ ] Panel otwiera się w ≤1 klatce od tapnięcia BonusesButton (brak async fetch, dane już w pamięci)
- [ ] GIVEN BonusesButton tapnięty gdy inny panel (Path/Settings) otwarty, THEN poprzedni panel zamyka się w tej samej klatce przed pojawieniem się Bonuses (Core Rule 4)
- [ ] GIVEN era_count == 0, WHEN panel otwarty, THEN wszystkie 4 wiersze widoczne z wartościami "0%"/"0.0" — żaden wiersz nie jest ukryty ani oznaczony jako zablokowany
- [ ] GIVEN META_BONUS_total[type] == META_BONUS_MAX[type] dla dowolnego typu, THEN ten wiersz pokazuje wskaźnik "MAX" (tekstowy/ikoniczny, nie tylko kolor paska) — accessibility Commitment 2
- [ ] Wszystkie interaktywne elementy (BonusesButton, CloseButton) mają touch target ≥44×44dp
- [ ] Close button, back-gesture (Android) i Esc (Web) prowadzą do identycznego zachowania zamknięcia — brak rozbieżności między metodami
- [ ] GIVEN dany typ bonusu otrzymał nowy grant odkąd panel był ostatnio zamknięty, WHEN panel otwarty ponownie, THEN ten wiersz pokazuje jednorazowy highlight puls; typy bez zmian nie pulsują
- [ ] GIVEN SettingsSystem.reduce_motion == true, THEN fade panelu skraca się do near-instant, a "świeży grant" highlight pozostaje opacity-only (bez ruchu)

---

## Open Questions

- **Ikony `BonusIcon` × 4 niezaprojektowane** — potrzebny asset spec, styl outline+flat fill bez highlightu per art-bible (2026-07-11 lock). *Owner: `/asset-spec system:meta-bonus-visibility`, po zatwierdzeniu tego spec'a.*
- **ADR-0014 napisany dla dokładnie 2 skoordynowanych paneli — ten spec dodaje trzeci.** `MainNavCoordinator`'s resolver-owy wzorzec (`_apply_state_change()`, `PANEL_OPEN` jako pojedynczy stan, nie enum-per-panel) generalizuje się bez zmian architektonicznych — `PANEL_OPEN` nie koduje KTÓRY panel, tylko że jeden jest widoczny. Ale ADR-0014's proza (Architecture Diagram, Migration Plan) explicite wymienia tylko `ClassPathPanel`/`SettingsScreen` i dwa pliki do rewiringu. Wymaga krótkiej rewizji ADR-0014 (dopisanie `BonusesPanel` jako trzeciego entry-point pary, nie nowego ADR) przed implementacją tego ekranu. *Owner: rewizja ADR-0014, przed story implementującą ten panel.*
- **Dokładne wartości "świeży grant" highlight** (intensywność, czas trwania) — kierunek ustalony (opacity-only), liczby do feel-testu. *Owner: po pierwszym playteście.*
- **Język UI (Polish→English audit)** — potwierdzone jako dotyczące tego ekranu, część już śledzonego, szerszego długu projektu. *Owner: istniejący audyt tłumaczenia, nie nowy dla tego ekranu.*
- **Brak `design/player-journey.md`** — ten spec projektowano bez mapy podróży gracza; założenia o kontekście emocjonalnym (Section B) są wywiedzione z GDD, nie z dedykowanej mapy. *Owner: przyszła sesja player-journey, jeśli powstanie.*
