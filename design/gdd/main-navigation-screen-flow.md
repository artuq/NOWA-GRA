# Main Navigation/Screen Flow

> **Status**: Designed (pending independent /design-review)
> **Creative Director Review (CD-GDD-ALIGN)**: Skipped — Lean mode
> **Author**: user + agents
> **Last Updated**: 2026-07-20
> **Implements Pillar**: Brak bezpośredniego mapowania (czysta infrastruktura prezentacyjna, jak Action UI/Card UI/Offline Report Screen) — pośrednio wspiera Pillar 4 (offline jako pierwsza klasa obywatelska), patrz Player Fantasy.

## Overview

Main Navigation/Screen Flow definiuje, jak gracz przechodzi między ekranami gry i jak te przejścia się czują — od zimnego startu (ekran boot, niewidoczny dla gracza) przez opcjonalny Raport Offline, aż po główny ekran gry, gdzie panele (Ścieżka Klasy, Ustawienia) otwierają się i zamykają bez szarpania czy nakładania na siebie. Dla gracza to niewidoczny szkielet, który sprawia, że gra **nigdy nie czuje się rozbita na osobne, niespójne ekrany** — każde przejście jest płynne, przewidywalne, i nigdy nie zostawia dwóch rzeczy na ekranie naraz walczących o uwagę.

Nawigacja między scenami (boot → opcjonalny Raport Offline → główny ekran) jest już zaprojektowana i zaimplementowana przez **ADR-0003** (Accepted) — ten GDD dokumentuje tę decyzję na poziomie projektowym (co gracz widzi i kiedy), nie przeprojektowuje jej. Nowa część, którą ten dokument faktycznie projektuje, to koordynacja nawigacji **wewnątrz** głównego ekranu: dziś panele Ścieżki Klasy i Ustawień otwierają się niezależnie, bez sprawdzania czy drugi jest już otwarty — realna luka, którą ten GDD zamyka.

## Player Fantasy

Gracz nigdy świadomie nie "używa" tego systemu — a jednak czuje go bez przerwy. Bezpośrednia warstwa jest namacalna i prosta: tapnięcie przycisku Path czy Settings otwiera panel od razu, bez opóźnienia; tapnięcie "Dalej" na Raporcie Offline zamyka go i wraca do gry w jednym gładkim ruchu. Pod spodem leży warstwa, której gracz nigdy nie widzi wprost, ale której **brak** natychmiast by zauważył: żaden panel nie zostaje otwarty "przypadkiem" razem z drugim, żadne przejście nie migocze, nic nie zostaje zamrożone między ekranami. To jest zaufanie budowane przez nieobecność problemów, nie przez efektowność — ten system nie ma być "fajny", ma być **niewidoczny w swojej poprawności**.

Nie mapuje się bezpośrednio na jeden konkretny Pillar (podobnie jak Action UI/Card UI/Offline Report Screen, które też są w dużej mierze infrastrukturą prezentacyjną) — ale pośrednio wspiera Pillar 4 (offline jako pierwsza klasa obywatelska): to właśnie ten system decyduje, czy Raport Offline pojawia się gładko na starcie, czy czuje się jak zgrzyt przed właściwą grą.

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents not consulted — Lean mode. Review manually before production.*

### Core Rules

**Zakres tego systemu**: nawigacja między-scenowa (boot → Raport Offline → główny ekran) jest już zaprojektowana i zaimplementowana przez ADR-0003 — poniższe reguły ją **dokumentują**, nie zmieniają. Reguły 4-7 to nowa specyfikacja: koordynacja nawigacji wewnątrz głównego ekranu.

1. **Kolejność scen na starcie** (ADR-0003, już shipowane): `boot.tscn` (niewidoczny) → jeśli offline ≥ 300s: `offline_report.tscn` → `main.tscn`. Jeśli offline < 300s: prosto do `main.tscn`, bez Raportu.
2. **`main.tscn` jest cienkim kontenerem** — instancjonuje `action_screen.tscn` jako jedyne dziecko. Cała dalsza nawigacja dzieje się wewnątrz `action_screen.tscn`, nie przez kolejne `change_scene_to_file()`.
3. **Panele overlay** (Ścieżka Klasy, Ustawienia) to instancjonowane rodzeństwo w `action_screen.tscn`, przełączane przez `visible` — nie osobne sceny.
4. **Zasada "co najwyżej jeden panel naraz"**: otwarcie panelu A, gdy panel B jest widoczny, automatycznie zamyka B w tej samej klatce, zanim A stanie się widoczny. Nigdy oba widoczne jednocześnie.
5. **Karta decyzji ma najwyższy priorytet**: gdy `DecisionCardSystem` wchodzi w stan `presenting` (sygnał `card_presented`), każdy otwarty panel (Ścieżka Klasy, Ustawienia) zamyka się automatycznie — **stan logiczny zmienia się natychmiast, w tej samej klatce**, bez czekania na żadną animację; wizualna warstwa fade to czysto kosmetyczny efekt na wierzchu już-zmienionego stanu (patrz Visual/Audio Requirements), nigdy nie opóźnia samej zmiany stanu.
6. **Systemowy gest "wstecz" (Android natywnie / iOS edge-swipe / przeglądarka Web)**:
   - Jeśli panel jest otwarty (`panel_open`, dotyczy tylko `action_screen.tscn`, nie Raportu Offline): gest zamyka ten panel, konsumowany, stan → `no_overlay`.
   - Jeśli karta jest widoczna (`card_presented`): gest **ignorowany** — ten sam precedens co Raport Offline, karta to najważniejszy moment w grze, nie omijalny przez wstecz.
   - Jeśli Raport Offline jest widoczny (osobna scena): gest **ignorowany** — już ustalone w Edge Cases, tylko dismiss zamyka.
   - Jeśli nic z powyższego nie jest widoczne: przechodzi do domyślnego zachowania platformy (Android/iOS: wyjście z aplikacji; Web: domyślna nawigacja przeglądarki — patrz Engine Notes).
   - **Engine Notes (ryzyko techniczne, wymaga weryfikacji przed implementacją)**: mechanizm przechwytywania "wstecz" fundamentalnie różni się między platformami — Android ma natywny hook (`NOTIFICATION_WM_GO_BACK_REQUEST`), iOS analogicznie przez edge-swipe, ale **Web nie ma równoważnego "systemowego" gestu w tym samym sensie** — przeglądarkowy przycisk Wstecz normalnie nawiguje historię strony i przechwycenie go wymaga dodatkowej techniki (`history.pushState`/`popstate` przez JS interop), niezweryfikowanej w tym projekcie (web-export spike wciąż w backlogu, per `technical-preferences.md`). Do potwierdzenia przez `godot-specialist` przy architekturze.
7. **Brak stosu nawigacji**: to nie jest wielopoziomowy back-stack — tylko dwa stany na raz: "żaden panel" i "jeden konkretny panel". Zamknięcie panelu zawsze wraca do głównego ekranu, nigdy do innego panelu.

### States and Transitions

| Stan | Opis | Przejście |
|---|---|---|
| `no_overlay` | Główny ekran w pełni interaktywny, żaden panel/karta widoczne | → `panel_open` (tap Path/Settings) lub → `card_presented` (DecisionCardSystem) |
| `panel_open` | Jeden panel widoczny (Ścieżka Klasy LUB Ustawienia) | → `no_overlay` (Close/dismiss/back) lub → `panel_open` innym panelem (przełączenie) lub → `card_presented` (karta przerywa, zamyka panel) |
| `card_presented` | Karta decyzji widoczna, blokuje wszystko inne | → `no_overlay` (karta rozwiązana) |

*(Powyższe to stan **koordynacji nawigacji**, nie duplikat wewnętrznych maszyn stanów `DecisionCardSystem`/`ClassPathPanel`/`SettingsScreen` — każdy z nich ma własną, już udokumentowaną maszynę stanów we własnym GDD; ta tabela opisuje tylko "co jest na wierzchu ekranu".)*

### Interactions with Other Systems

- **Action UI** (peer, hard) → `action_screen.tscn` jest hostem — PathButton/SettingsButton żyją w jego TopBarze (już shipowane).
- **Class Path System (Full)** (hard, read) → `ClassPathPanel` to jego widok prezentacyjny, uczestniczy w regule "co najwyżej jeden panel".
- **Settings System** (hard, read) → `SettingsScreen` analogicznie.
- **Decision Card System** (hard, read) → `card_presented`/`card_resolved` to sygnały, na których ten system nasłuchuje, by wymusić regułę 5 (priorytet karty).
- **Offline Report Screen** (hard, read) → konsumuje scenę `offline_report.tscn`, już rozwiązane przez ADR-0003.

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

Ten GDD nie wprowadza żadnej matematyki gry ani wyprowadzenia liczbowego — w przeciwieństwie do sąsiednich GDD (Action UI, Card UI, Offline Report Screen), które miały choć jedną drobną formułę prezentacyjną (np. `fill_ratio`, `rotation_degrees`), ten system to czysta koordynacja stanu widoczności (`visible` — wartość logiczna, nie interpolowana). Zero zmiennych, zero wyprowadzeń.

Jeden potencjalnie liczbowy element — debounce zabezpieczający przed migotaniem przy bardzo szybkim podwójnym tapnięciu (Reguła 4: przełączenie paneli "w tej samej klatce") — nie jest formułą (brak zmiennych/obliczenia), tylko pojedynczą stałą. Przeniesiony do Edge Cases (opis warunku wyścigu) i Tuning Knobs (wartość stałej), zgodnie z konwencją tego projektu (`save_debounce_interval_sec` w Save/Persistence to ten sam wzorzec: stała, nie formuła).

## Edge Cases

> *Specialist not consulted — Lean mode (section is not D/H).*

- **Jeśli gracz tapnie Path i Settings bardzo szybko po sobie (w granicy jednej-dwóch klatek)**: przetwarzane sekwencyjnie, w kolejności zdarzeń wejścia — każde tapnięcie zamyka poprzedni panel i otwiera nowy, zgodnie z Regułą 4. Brak specjalnego debounce na to — to zamierzone zachowanie "ostatnie tapnięcie wygrywa", nie błąd.
- **Jeśli karta decyzji (`card_presented`) pojawia się dokładnie w momencie, gdy panel jest w trakcie otwierania (ta sama klatka co tapnięcie Path/Settings)**: karta ma priorytet bezwzględny (Reguła 5) — panel nigdy nie kończy się otwierać w pełni widoczny; jeśli oba zdarzenia trafiają w tę samą klatkę, końcowy stan to zawsze `card_presented`, nigdy `panel_open`.
- **Jeśli dwa panele próbowałyby otworzyć się w tej samej klatce** (teoretycznie, gdyby dwa różne wywołania trafiły jednocześnie): deterministyczne — ostatnie wywołanie w kolejce sygnałów wygrywa, zgodnie z Godota kolejnością przetwarzania sygnałów w jednej klatce (brak równoległości w GDScript).

*(Zachowanie gestu "wstecz" we wszystkich trzech kontekstach — panel otwarty, karta widoczna, Raport Offline widoczny, nic widoczne — jest teraz w pełni opisane w Core Rules, Regule 6, nie duplikowane tutaj.)*

## Dependencies

**Upstream (ten system zależy od):**
- **Action UI** (hard) — `action_screen.tscn` jest hostem, PathButton/SettingsButton żyją w jego TopBarze.
- **Class Path System (Full)** (hard) — `ClassPathPanel` jako jeden z koordynowanych overlayów.
- **Settings System** (hard) — `SettingsScreen` jako drugi koordynowany overlay. *(Ten system nie ma jeszcze własnego GDD — udokumentowany tu jako zależność mimo braku formalnego dokumentu źródłowego, ta sama konwencja co Action UI stosuje wobec swoich niezaprojektowanych zależności.)*
- **Decision Card System** (hard) — sygnały `card_presented`/`card_resolved` wymuszające Regułę 5.
- **Offline Report Screen** (hard) — scena konsumowana w kroku boot, już rozwiązane przez ADR-0003.

**Downstream (zależy od tego systemu):**
- Brak — to najbardziej downstream element warstwy UI w obecnym systems-index.

*(Niespójność dwukierunkowa znaleziona i naprawiona w tej samej sesji: `design/gdd/class-path-system.md`'s sekcja "Depended on by" nie wymieniała tego systemu — dopisana.)*

## Tuning Knobs

Brak — ten system to czysta koordynacja logiczna (Formulas: żadnej matematyki; Edge Cases: brak debounce to świadoma decyzja, "ostatnie tapnięcie wygrywa"), bez żadnej wartości do strojenia. Panele przełączają widoczność natychmiast (`visible = true/false`), bez animacji przejścia zdefiniowanej w Core Rules — jeśli w przyszłości dojdzie fade/slide, jego czas trwania stanie się pierwszym knobem tego systemu, ale to wymaga najpierw dopisania reguły w Core Rules, nie odwrotnie.

## Visual/Audio Requirements

> *Specialist consulted: `art-director` — category is "UI systems," mandatory for Visual/Audio.*

- **Przejście paneli**: nie instant flip (dziś: `visible = true/false` bez animacji) — to odstawałoby od już zatwierdzonych sąsiadów (Card UI: 150-200ms wejście, Offline Report: animowany dismiss). Fade, nie slide: otwarcie ~120-150ms ease-out, zamknięcie ~100ms ease-in (szybsze zamknięcie niż otwarcie to standardowa konwencja, ważna przy szybkim wielokrotnym tapnięciu Path/Settings). Tylko opacity — bez slide/scale, zgodnie z zasadą art-bible "near-zero decoration, każdy element load-bearing".
- **Wymuszone zamknięcie przez kartę** (Reguła 5): identyczne jak zwykłe zamknięcie — **bez** specjalnego "przerwanego" wyglądu. Wizualne wyróżnienie przerwania byłoby małym dramatycznym gestem, sprzecznym z rejestrem "precyzja bez osądu" (art-bible §1). Praktycznie: pomiń animację zamknięcia w tym przypadku (cięcie prosto do ukrycia) — pełnoekranowa scrim karty i tak natychmiast to zakrywa, więc nic nie tracimy, a unikamy kolizji dwóch animacji w tej samej klatce.
- **Audio**: brak. Gra ma trwale zablokowane audio (decyzja zatwierdzona 2026-07-12, `design/art/art-bible.md` §8) — to nadpisuje wcześniejsze założenie "Moderate audio needs" z `game-concept.md`, które powstało przed tą decyzją. *(Uwaga poza zakresem: `offline-report-screen.md`'s własna sekcja Audio — stinger/tick/thud — jest teraz nieaktualna i wymaga osobnej korekty w przyszłości.)*

📌 **Asset Spec** — once the art bible is approved, run `/asset-spec system:main-navigation-screen-flow`.

## UI Requirements

- Panele overlay muszą blokować interakcję z Action UI/Resource HUD/Action Grid poniżej przez cały czas widoczności — ten sam wzorzec co Card UI już ustaliło dla siebie.
- Przycisk Close na każdym panelu i systemowy gest "wstecz" muszą prowadzić do identycznego zachowania (Reguła 6/7) — brak rozbieżności między metodami zamknięcia.
- Zero hover-only interakcji, standardowy `Button`, per `technical-preferences.md` (już przestrzegane przez `PathButton`/`SettingsButton`/`CloseButton` w obecnym kodzie).

> 📌 **UX Flag — Main Navigation/Screen Flow**: Ten system koordynuje istniejące ekrany, nie tworzy nowego — nie wymaga własnego `/ux-design` spec (w przeciwieństwie do Action UI/Card UI/Offline Report Screen, które już mają swoje flagi). Jeśli w przyszłości dojdzie animacja fade (Visual/Audio Requirements), jej dokładne krzywe easingu mogą trafić do UX spec jednego z istniejących ekranów, nie nowego dokumentu.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**Kolejność scen (Reguła 1 — ADR-0003, regresja):**
- GIVEN offline ≥ 300s przy zimnym starcie, WHEN `boot.tscn` kończy, THEN `offline_report.tscn` ładuje się przed `main.tscn`.
- GIVEN offline < 300s, WHEN `boot.tscn` kończy, THEN `main.tscn` ładuje się bezpośrednio.
- GIVEN `boot.tscn` działa, THEN nigdy nie renderuje widocznej treści.

**Kompozycja ekranu (Reguły 2-3):**
- GIVEN `main.tscn` załadowany, THEN `action_screen.tscn` to jego jedyne dziecko.
- GIVEN nawigacja wewnątrz `action_screen.tscn` (Path, Settings), THEN żadne `change_scene_to_file()` nie jest wywoływane.
- GIVEN `ClassPathPanel`/`SettingsScreen` istnieją, THEN zawsze obecne jako rodzeństwo, przełączane przez `visible` — nigdy instancjonowane/zwalniane na żądanie.

**Co najwyżej jeden panel (Reguła 4):**
- GIVEN `panel_open`/ClassPathPanel, WHEN gracz tapnie Settings, THEN `ClassPathPanel.visible=false` i `SettingsScreen.visible=true` w tej samej klatce — nigdy oba `true` jednocześnie.
- GIVEN `no_overlay`, WHEN tap Path, THEN → `panel_open` (ClassPathPanel).

**Priorytet karty (Reguła 5):**
- GIVEN `panel_open`, WHEN `card_presented` emitowany, THEN widoczny panel staje się `visible=false` natychmiast, w tej samej klatce, bez animacji zamknięcia, przed pojawieniem się karty.
- GIVEN `no_overlay`, WHEN `card_presented`, THEN → `card_presented` bezpośrednio.
- GIVEN `card_presented`, WHEN `card_resolved`, THEN → `no_overlay` — nigdy bezpośrednio do `panel_open`, nawet jeśli panel był otwarty przed przerwaniem.

**Gest "wstecz" (Reguła 6, wszystkie platformy):**
- GIVEN `panel_open`, WHEN gest wstecz (Android/iOS/Web), THEN panel się zamyka → `no_overlay`, gest skonsumowany.
- GIVEN `card_presented`, WHEN gest wstecz, THEN **ignorowany** — karta pozostaje widoczna.
- GIVEN Raport Offline widoczny, WHEN gest wstecz, THEN **ignorowany** — tylko dismiss zamyka.
- GIVEN `no_overlay` i Raport Offline nieaktywny, WHEN gest wstecz, THEN domyślne zachowanie platformy (Android/iOS: wyjście; Web: domyślna nawigacja przeglądarki).

**Brak stosu (Reguła 7):**
- GIVEN `panel_open`, WHEN zamknięty jakąkolwiek metodą, THEN → `no_overlay` zawsze — nigdy do innego panelu.

**Maszyna stanów:**
- GIVEN dowolny moment, THEN system koordynacji jest dokładnie w jednym z 3 stanów — nigdy 4. stan, nigdy dwa jednocześnie.

**Edge cases:**
- GIVEN tap Path potem Settings w 1-2 klatkach, THEN przetworzone sekwencyjnie, stan końcowy `panel_open`/Settings, brak debounce.
- GIVEN tap panelu i `card_presented` w tej samej klatce, THEN stan końcowy zawsze `card_presented`.

**Nietestowalne wobec samego tego GDD:**
- Dokładne wartości fade (120-150ms/100ms) — podane jako przybliżone zakresy w Visual/Audio Requirements, nie zablokowane liczby.
- Wewnętrzna treść `SettingsScreen` po otwarciu — brak własnego GDD.
- Mechanizm przechwytywania "wstecz" na Web — niezweryfikowany technicznie (web-export spike w backlogu), patrz Engine Notes przy Regule 6.

## Open Questions

- **Mechanizm przechwytywania gestu "wstecz" na Web** — wymaga weryfikacji technicznej (JS interop `history.pushState`/`popstate` czy inna technika), zależne od jeszcze niewykonanego web-export spike. *Owner: `godot-specialist` przy architekturze, po web-export spike. Target: przed implementacją Reguły 6 dla platformy Web.*
- **Dokładne wartości fade** (dziś: przybliżone zakresy 120-150ms/100ms w Visual/Audio Requirements) — do zablokowania w `/ux-design`, jeśli powstanie UX spec dla jednego z istniejących ekranów. *Owner: nieprzypisany. Target: Pre-Production.*
- *(Poza zakresem tego GDD, znalezione przy okazji)*: `offline-report-screen.md`'s sekcja Audio (stinger/tick/thud) jest nieaktualna po decyzji o trwałym braku audio (2026-07-12) — wymaga osobnej korekty. *Owner: rewizja `offline-report-screen.md`. Target: nieprzypisany.*
