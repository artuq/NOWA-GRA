# Main Navigation/Screen Flow

> **Status**: Revised — blocking items from /design-review (full mode, 6 specialists + creative-director synthesis) addressed, pending re-review
> **Creative Director Review (CD-GDD-ALIGN)**: Full /design-review synthesis, 2026-07-21 — verdict NEEDS REVISION, 7 blocking items (all resolved in this revision: CardScreen mirror-not-hub boundary, "same frame" test semantics, fuzz-test AC rewrite, Android Quit-On-Go-Back requirement, Web back-gesture confirm mitigation, triple-collision AC, Settings auto-save data-loss check), 8 recommended revisions resolved, 1 architecture flag (CardScreen coordination boundary) carried forward to /create-architecture
> **Author**: user + agents
> **Last Updated**: 2026-07-21
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
6. **Systemowy gest "wstecz" (Android natywnie / iOS edge-swipe / przeglądarka Web)** — logika wewnętrzna (platform-agnostyczna, testowalna już dziś niezależnie od tego, czy dana platforma potrafi w ogóle dostarczyć zdarzenie "wstecz" do handlera — patrz Engine Notes i Acceptance Criteria):
   - Jeśli panel jest otwarty (`panel_open`, dotyczy tylko `action_screen.tscn`, nie Raportu Offline): gest zamyka ten panel, konsumowany, stan → `no_overlay`.
   - Jeśli karta jest widoczna (`card_presented`): gest **ignorowany** — ten sam precedens co Raport Offline, karta to najważniejszy moment w grze, nie omijalny przez wstecz.
   - Jeśli Raport Offline jest widoczny (osobna scena): gest **ignorowany** — już ustalone w Edge Cases, tylko dismiss zamyka.
   - Jeśli nic z powyższego nie jest widoczne: przechodzi do domyślnego zachowania platformy — Android/iOS: wyjście z aplikacji; **Web: NIE od razu domyślna nawigacja przeglądarki** — patrz nowa reguła "Web back-gesture confirm" niżej i Engine Notes.
   - **Web back-gesture confirm (dodane po `/design-review`, ux-designer + creative-director finding — rozstrzygnięte na rzecz mitygacji UX teraz, nie tylko odłożenia do web-export spike)**: na Web, gdy nic z powyższego (panel/karta/Raport Offline) nie jest widoczne i gest "wstecz" (przycisk przeglądarki) trafia do handlera, **pierwsze wywołanie pokazuje lekki confirm** ("Opuścić grę?" / "Leave game?", modal minimalny, zgodny z art-bible "near-zero decoration") zamiast od razu nawigować poza domenę gry — dopiero potwierdzenie tego promptu (osobny tap) pozwala na faktyczne domyślne zachowanie przeglądarki. To jest kontrakt UX niezależny od tego, czy prawdziwe "skonsumowanie" `popstate` okaże się technicznie możliwe (patrz Engine Notes) — nawet jeśli przechwycenie samego zdarzenia wstecz zawiedzie, ten confirm jest tym, co faktycznie chroni przed niezamierzoną utratą sesji. Testowalne już dziś jako osobny UI flow, niezależnie od nierozwiązanego jeszcze mechanizmu przechwytywania.
   - **Engine Notes (ryzyko techniczne, wymaga weryfikacji przed implementacją — DWIE platformy niezweryfikowane, nie jedna)**:
     - **Android**: natywny hook `NOTIFICATION_WM_GO_BACK_REQUEST` — mechanizm potwierdzony. **Nie jest to jednak samodzielnie "niskie ryzyko"** (poprawione po `/design-review`, godot-specialist finding, WebSearch-zweryfikowane przeciw Godot 4.6): dostarczenie/zachowanie tej notyfikacji jest bramkowane przez ustawienie projektu **"Quit On Go Back"** (Project Settings → Application/Config, domyślnie **włączone**) — jeśli zostawione na domyślnej wartości, system operacyjny może zamknąć aplikację na geście wstecz niezależnie od tego, co robi wewnętrzny handler z tej reguły. Wymaga jawnego ustawienia `get_tree().set_quit_on_go_back(false)` (lub odpowiednika w Project Settings) jako **wymogu architektonicznego tego systemu**, nie tylko podłączenia zdarzenia — inaczej handler jest częściowo martwym kodem na części urządzeń. Dodatkowo: możliwy wciąż-otwarty bug silnika dot. podwójnej emisji tej notyfikacji (godotengine/godot#105324, niepotwierdzony dla 4.6.3) — wart smoke-testu, nie blokujący.
     - **iOS**: GDD wcześniej zakładał "ten sam mechanizm co Android" — **to założenie jest prawdopodobnie błędne** (`godot-specialist` review, 2026-07-20): `NOTIFICATION_WM_GO_BACK_REQUEST` jest specyficzny dla Androida; iOS nie ma tego samego hooka systemowego przechwytywanego przez Godota w ten sam sposób. Wymaga osobnej weryfikacji technicznej, nie założenia równoważności — patrz Open Questions.
     - **Web**: nie ma równoważnego "systemowego" gestu w tym samym sensie — przeglądarkowy przycisk Wstecz normalnie nawiguje historię strony; przechwycenie wymaga dodatkowej techniki przez `JavaScriptBridge` (np. `history.pushState`/`popstate`), a prawdziwe "skonsumowanie" cofnięcia (jak na Androidzie) może nie być możliwe — realistycznie tylko reakcja *po* `popstate` i kompensacyjny push stanu, co jest UX-owo inne niż prawdziwy intercept. Niezweryfikowane w tym projekcie (web-export spike wciąż w backlogu, per `technical-preferences.md`). Do potwierdzenia przez `godot-specialist` przy architekturze — ale patrz powyżej: nawet bez rozwiązania tego mechanizmu, Web back-gesture confirm daje testowalną UX-ową siatkę bezpieczeństwa już teraz.
7. **Brak stosu nawigacji**: to nie jest wielopoziomowy back-stack — tylko dwa stany na raz: "żaden panel" i "jeden konkretny panel". Zamknięcie panelu zawsze wraca do głównego ekranu, nigdy do innego panelu. **Brak ryzyka utraty danych (zweryfikowane w kodzie po `/design-review`, ux-designer finding)**: `SettingsScreen` (`settings_screen.gd`) commituje każdą zmianę natychmiast przez `SettingsSystem.set_reduce_motion()` (persystuje w tej samej klatce, oznacza SaveSystem jako dirty) — nie ma stanu "niezapisane zmiany". Przerwanie przez kartę (Reguła 5) nigdy nie gubi danych gracza, tylko kontekst UI (gdzie był w panelu) — patrz Open Questions dla tego drugiego, mniejszego problemu.

**Definicja "w tej samej klatce" (dodane po `/design-review`, qa-lead + systems-designer finding — poprzednia wersja nie miała precyzyjnej semantyki testowej)**: wszędzie, gdzie ten dokument mówi "w tej samej klatce" (Reguły 4-6, Edge Cases), oznacza to konkretnie: w obrębie jednego **synchronicznego wywołania funkcji-resolvera** koordynatora, bez granicy klatki/yield między przyczyną (tap/sygnał/gest) a skutkiem (zmiana `coordination_state` i wynikających z niej flag `visible`) — nie "gdziekolwiek w obrębie tej samej klatki procesu", bo GDScript nie gwarantuje kolejności niezależnych handlerów sygnałów podłączonych osobno w obrębie jednej klatki. **Wymóg implementacyjny**: koordynator MUSI rozwiązywać każdą zmianę stanu jednym synchronicznym resolverem (jedna funkcja wywoływana bezpośrednio z handlera zdarzenia wywołującego), nie przez niezależne, równoległe nasłuchiwacze na osobny sygnał `state_changed` — inaczej kolejność podłączeń sygnałów w Godocie (nigdzie w tym dokumencie nieprzypięta) stałaby się cicho krytyczna dla poprawności Reguły 5's gwarancji "panel znika zanim karta się pojawia" (systems-designer finding).

### States and Transitions

| Stan | Opis | Przejście |
|---|---|---|
| `no_overlay` | Główny ekran w pełni interaktywny, żaden panel/karta widoczne | → `panel_open` (tap Path/Settings) lub → `card_presented` (DecisionCardSystem) |
| `panel_open` | Jeden panel widoczny (Ścieżka Klasy LUB Ustawienia) | → `no_overlay` (Close/dismiss/back) lub → `panel_open` innym panelem (przełączenie) lub → `card_presented` (karta przerywa, zamyka panel) |
| `card_presented` | Karta decyzji widoczna, blokuje wszystko inne | → `no_overlay` (karta rozwiązana) |

*(Powyższe to stan **koordynacji nawigacji**, nie duplikat wewnętrznych maszyn stanów `DecisionCardSystem`/`ClassPathPanel`/`SettingsScreen` — każdy z nich ma własną, już udokumentowaną maszynę stanów we własnym GDD; ta tabela opisuje tylko "co jest na wierzchu ekranu".)*

**Reprezentacja implementacyjna (dodane po `/design-review`, qa-lead finding)**: te 3 stany to nie luźny opis — koordynator (skrypt na korzeniu `action_screen.tscn`) przechowuje je jako pojedynczą zmienną `coordination_state: CoordinationState` (enum: `NO_OVERLAY`, `PANEL_OPEN`, `CARD_PRESENTED`), jedno źródło prawdy dla **dwóch paneli, które ten koordynator faktycznie posiada**: `ClassPathPanel.visible` i `SettingsScreen.visible` są *skutkiem* zmiany `coordination_state`, nie jego definicją — nie są wywodzone ad-hoc z niezależnych flag na tych węzłach.

**Granica z `CardScreen` — mirror, nie hub (rozstrzygnięte po `/design-review`, ui-programmer finding — poprzednia wersja tego twierdzenia była niejednoznaczna wobec `action_screen.gd`'s własnego komentarza, że karta świadomie NIE jest hubowana przez ten skrypt, per ADR-0007)**: `coordination_state` **odczytuje** `DecisionCardSystem.card_presented`/`card_resolved`, żeby wiedzieć kiedy przejść do/z `CARD_PRESENTED` i zamknąć swoje dwa panele — ale **nigdy nie zapisuje** `CardScreen.visible`. Widoczność `CardScreen` pozostaje w pełni samo-zarządzana przez `DecisionCardSystem`'s sygnały, dokładnie jak dziś (`card_screen.gd`) — koordynator jest subskrybentem tego sygnału, nie jego właścicielem. Skutek: `coordination_state == CARD_PRESENTED` jest zawsze zgodne z tym, że `CardScreen` jest widoczny, ale to zgodność przez współdzielone źródło sygnału (oba nasłuchują tego samego `DecisionCardSystem` zdarzenia), nie przez to, że jedno kontroluje drugie — nie ma rewiringu istniejącego połączenia `card_screen.gd`, nie ma nowej zależności zapisu przez granicę ADR-0007.

### Interactions with Other Systems

- **Action UI** (peer, hard) → `action_screen.tscn` jest hostem — PathButton/SettingsButton żyją w jego TopBarze (już shipowane).
- **Class Path System (Full)** (hard, read) → `ClassPathPanel` to jego widok prezentacyjny, uczestniczy w regule "co najwyżej jeden panel".
- **Settings System** (hard, read) → `SettingsScreen` analogicznie.
- **Decision Card System** (hard, read) → `card_presented`/`card_resolved` to sygnały, na których ten system nasłuchuje, by wymusić regułę 5 (priorytet karty).
- **Offline Report Screen** (hard, read) → konsumuje scenę `offline_report.tscn`, już rozwiązane przez ADR-0003.

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

Ten GDD nie wprowadza żadnej matematyki gry ani wyprowadzenia liczbowego — w przeciwieństwie do sąsiednich GDD (Action UI, Card UI, Offline Report Screen), które miały choć jedną drobną formułę prezentacyjną (np. `fill_ratio`, `rotation_degrees`), ten system to czysta koordynacja stanu widoczności (`visible` — wartość logiczna, nie interpolowana). Zero zmiennych, zero wyprowadzeń.

Reguła 4 (przełączenie paneli "w tej samej klatce") mogłaby sugerować potrzebę debounce zabezpieczającego przed migotaniem przy bardzo szybkim podwójnym tapnięciu — **świadomie go tu nie ma** (patrz Edge Cases: "ostatnie tapnięcie wygrywa" to zamierzone zachowanie, nie luka wymagająca stałej). *(Poprawione po `/design-review`: wcześniejsza wersja tej sekcji błędnie zapowiadała stałą debounce w Tuning Knobs — ta stała nigdy nie istniała, usunięto sprzeczność.)*

## Edge Cases

> *Specialist not consulted — Lean mode (section is not D/H).*

- **Jeśli gracz tapnie Path i Settings bardzo szybko po sobie (w granicy jednej-dwóch klatek)**: przetwarzane sekwencyjnie, w kolejności zdarzeń wejścia — każde tapnięcie zamyka poprzedni panel i otwiera nowy, zgodnie z Regułą 4. Brak specjalnego debounce na to — to zamierzone zachowanie "ostatnie tapnięcie wygrywa", nie błąd.
- **Jeśli karta decyzji (`card_presented`) pojawia się dokładnie w momencie, gdy panel jest w trakcie otwierania (ta sama klatka co tapnięcie Path/Settings)**: karta ma priorytet bezwzględny (Reguła 5) — panel nigdy nie kończy się otwierać w pełni widoczny; jeśli oba zdarzenia trafiają w tę samą klatkę, końcowy stan to zawsze `card_presented`, nigdy `panel_open`.
- **Jeśli dwa panele próbowałyby otworzyć się w tej samej klatce** (teoretycznie, gdyby dwa różne wywołania trafiły jednocześnie): deterministyczne — ostatnie wywołanie w kolejce sygnałów wygrywa, zgodnie z Godota kolejnością przetwarzania sygnałów w jednej klatce (brak równoległości w GDScript).
- **Jeśli gest "wstecz" i `card_presented` trafiają w tę samą klatkę** (dodane po `/design-review`, systems-designer finding — poprzednia wersja nie pokrywała tej kombinacji): **priorytet karty wygrywa** — ten sam precedens co Reguła 5 wobec zwykłego tapnięcia panelu. Końcowy stan to zawsze `card_presented`; gest "wstecz" jest w tej klatce efektywnie ignorowany, tak jakby karta była już widoczna (Reguła 6, druga linia).
- **Jeśli gest "wstecz" i tapnięcie Path/Settings trafiają w tę samą klatkę** (dodane po `/design-review`): **gest "wstecz" wygrywa** — jeśli panel A był otwarty, gest go zamyka (→ `no_overlay`) niezależnie od jednoczesnego tapnięcia próbującego otworzyć panel B; tapnięcie B w tej samej klatce jest efektywnie ignorowane. Ogólna kolejność priorytetu przy kolizji wielu zdarzeń w jednej klatce: **`card_presented` > gest "wstecz" > tapnięcie panelu**.
- **Trójkolizja: gest "wstecz" + tapnięcie panelu + `card_presented` w tej samej klatce** (dodane po `/design-review`, systems-designer finding — poprzednio tylko wywodzone transytywnie z ogólnej kolejności priorytetu powyżej, nigdy jawnie stwierdzone ani pokryte osobną AC): `card_presented` wygrywa nad obydwoma pozostałymi jednocześnie — stan końcowy to zawsze `card_presented`, niezależnie od tego, że dwa inne zdarzenia trafiły w tę samą klatkę. To bezpośrednia konsekwencja kolejności priorytetu (`card_presented` > gest wstecz > tap panelu), ale teraz jawnie pokryta osobną Acceptance Criteria (patrz niżej), nie tylko wywodzona.
- **Jeśli `card_resolved` zostanie wyemitowany, gdy `coordination_state` nie jest `CARD_PRESENTED`** (dodane po `/design-review`, systems-designer finding — duplikat sygnału lub race w `DecisionCardSystem`, np. podwójna emisja): ignorowane, no-op — stan pozostaje bez zmian. Jedyne poprawne przejście z `CARD_PRESENTED` to `card_resolved` przyjęty dokładnie raz na jedno wcześniejsze wejście przez `card_presented`; drugi/nieoczekiwany `card_resolved` nigdy nie cofa stanu do `panel_open` ani nie robi nic innego.

*(Zachowanie gestu "wstecz" we wszystkich trzech kontekstach — panel otwarty, karta widoczna, Raport Offline widoczny, nic widoczne — jest teraz w pełni opisane w Core Rules, Regule 6, nie duplikowane tutaj; powyższe dwie pozycje pokrywają tylko kolizje **między** gestem "wstecz" a innymi zdarzeniami w tej samej klatce.)*

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

- **Przejście paneli**: nie instant flip (dziś: `visible = true/false` bez animacji) — to odstawałoby od już zatwierdzonych sąsiadów (Card UI: 150-200ms wejście, Offline Report: animowany dismiss). Fade, nie slide: otwarcie ~120-150ms ease-out, zamknięcie ~100ms ease-in (szybsze zamknięcie niż otwarcie to standardowa konwencja, ważna przy szybkim wielokrotnym tapnięciu Path/Settings). Tylko opacity — bez slide/scale, zgodnie z zasadą art-bible "near-zero decoration, każdy element load-bearing". **Reduce Motion** (dodane po `/design-review`, ux-designer finding — `SettingsScreen`'s już zaimplementowany toggle wcześniej nie był tu wspomniany): gdy `SettingsSystem.reduce_motion` jest włączone, ten fade skraca się do near-instant (≤1 klatka) zamiast pełnego czasu trwania — ta sama konwencja co inne animowane elementy pod tym flagą (art-bible §7 MANDATE). **Brak migotania przy szybkim przełączeniu (dodane po `/design-review`, game-designer finding — poprzednia wersja nie precyzowała tego przypadku, ryzykując sprzeczność z Player Fantasy "nic nie miga")**: gdy nowe otwarcie panelu B przerywa jeszcze trwającą animację zamknięcia panelu A (Reguła 4, "ostatnie tapnięcie wygrywa"), fade zamknięcia A jest natychmiast anulowany (cięcie do ukrycia, nie dogrywany do końca) zanim zacznie się fade otwarcia B — dwie animacje nigdy nie nakładają się wizualnie w tym samym momencie, więc szybkie podwójne tapnięcie daje czyste zamknięcie-potem-otwarcie, nie migotanie dwóch półprzezroczystych warstw naraz.
- **Zgodność Close/gest wstecz (dodane po `/design-review`, ux-designer finding — poprzednio niesprecyzowane)**: przycisk Close i gest "wstecz" (Reguła 6/7) zawsze odtwarzają identyczną animację zamknięcia panelu — ten sam ~100ms fade ease-in jak każde inne zamknięcie, nigdy cięcie na sucho dla jednej metody a fade dla drugiej.
- **Refusal feedback przy zignorowanym geście wstecz podczas `card_presented`** (dodane po `/design-review`, game-designer + creative-director finding — poprzednio czysto Open Question bez żadnej spec'owanej reakcji; audio trwale wyłączone więc jedyny dostępny kanał to wizualny): gdy gest "wstecz" trafia do handlera podczas `card_presented` i zostaje zignorowany (Reguła 6, druga linia), pełnoekranowa scrim karty wykonuje subtelny, krótki puls (jednorazowe, delikatne rozjaśnienie/przyciemnienie opacity scrimu, ≤150ms, bez migotania — zgodne z Reduce Motion: pomijane całkowicie gdy flaga włączona) — sygnalizuje "zarejestrowałem twój gest, ale karta ma priorytet", zamiast całkowitego milczenia, które czytałoby się jak zawieszona aplikacja. Wart feel-testu przed finalnym zatwierdzeniem wartości pulsu, ale spec'owany teraz jako miękki wymóg, nie odłożony bezterminowo.
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

**Gest "wstecz" — wewnętrzny handler (Reguła 6, platform-agnostyczne, testowalne już dziś przez bezpośrednie wywołanie handlera, niezależnie od tego czy dana platforma potrafi dostarczyć do niego zdarzenie):**
- GIVEN `panel_open`, WHEN handler "wstecz" wywołany, THEN panel się zamyka → `no_overlay`, zdarzenie skonsumowane.
- GIVEN `card_presented`, WHEN handler "wstecz" wywołany, THEN **ignorowane** — karta pozostaje widoczna.
- GIVEN Raport Offline widoczny, WHEN handler "wstecz" wywołany, THEN **ignorowane** — tylko dismiss zamyka.
- GIVEN `no_overlay` i Raport Offline nieaktywny, WHEN handler "wstecz" wywołany, THEN domyślne zachowanie platformy (Android/iOS: wyjście; Web: domyślna nawigacja przeglądarki).

**Gest "wstecz" — dostarczenie zdarzenia z platformy do handlera, per platforma (BLOKOWANE, rozdzielone od powyższego po `/design-review`, ux-designer + qa-lead + godot-specialist finding — poprzednia wersja traktowała Android/iOS/Web jako jednakowo gotowe do testu, co nie jest prawdą):**
- **Android**: `NOTIFICATION_WM_GO_BACK_REQUEST` potwierdzony jako właściwy hook — GIVEN natywny gest/przycisk wstecz na Androidzie, WHEN Godot emituje tę notyfikację, THEN wywołuje się wewnętrzny handler powyżej. **Dodatkowy warunek gotowości (dodane po `/design-review`, godot-specialist finding, WebSearch-zweryfikowane przeciw 4.6)**: GIVEN projekt ma `Application/Config/Quit On Go Back` jawnie ustawione na `false` (nie domyślną wartość `true`), WHEN gest wstecz przychodzi, THEN system operacyjny NIE zamyka aplikacji automatycznie przed dotarciem do wewnętrznego handlera — bez tego ustawienia AC powyżej jest częściowo martwa na realnym urządzeniu. Nie ship'ować Androida jako "gotowe" bez weryfikacji tego ustawienia w exporcie.
- **iOS**: **BLOKOWANE** — mechanizm przechwytywania edge-swipe na iOS w Godocie 4.6.3 niezweryfikowany (wcześniejsze założenie "ten sam mechanizm co Android" odrzucone, patrz Engine Notes przy Regule 6). Nie testować jako gotowe, dopóki `godot-specialist` nie potwierdzi mechanizmu. **Warunek odblokowania (dodane po `/design-review`, qa-lead finding)**: GIVEN `godot-specialist` potwierdzi konkretny mechanizm przechwytywania edge-swipe na iOS w Godocie 4.6.3 (przy `/create-architecture` lub dedykowanym spike'u), THEN ta AC zostaje przepisana z potwierdzonym API i dodany zostaje test na fizycznym urządzeniu przed zmianą statusu z BLOKOWANE.
- **Web**: **CZĘŚCIOWO ODBLOKOWANE (poprawione po `/design-review`)** — mechanizm prawdziwego przechwycenia `popstate` wciąż **BLOKOWANE**, niezweryfikowany, zależny od web-export spike (wciąż w backlogu). Ale ryzyko sesji-utraty ma teraz osobną, testowalną warstwę mitygacji: GIVEN `no_overlay` i Raport Offline nieaktywny na Web, WHEN gest wstecz (przeglądarki) trafia do handlera po raz pierwszy, THEN pokazuje się confirm "Opuścić grę?" zamiast natychmiastowej nawigacji — testowalne już dziś jako osobny UI flow (patrz Core Rules, "Web back-gesture confirm"), niezależnie od tego czy prawdziwe przechwycenie `popstate` się uda. **Warunek odblokowania dla właściwego mechanizmu przechwytywania (dodane po `/design-review`, qa-lead finding)**: GIVEN `godot-specialist` potwierdzi konkretną technikę `JavaScriptBridge`/`popstate` po web-export spike, THEN ta AC zostaje przepisana i status zmienia się z BLOKOWANE na gotowe do testu na faktycznej platformie Web. Nie ship'ować głębokiego mechanizmu przechwytywania jako rozwiązanego, ale confirm-dialog UX jest już częścią kontraktu tej wersji GDD.

**Brak stosu (Reguła 7):**
- GIVEN `panel_open`, WHEN zamknięty jakąkolwiek metodą, THEN → `no_overlay` zawsze — nigdy do innego panelu.

**Maszyna stanów (przepisane DRUGI RAZ po `/design-review`, qa-lead finding — poprzednia wersja, mimo że sama nazywała się "przepisaną", wciąż wymagała losowego seeda zakazanego przez `coding-standards.md` i asercji, którą system typów GDScript i tak gwarantuje mechanicznie, więc nic realnego nie testowała):**
- GIVEN ustalona, deterministyczna, zaszytą-na-sztywno sekwencja zdarzeń testowych (nie losowy fuzz — konkretna, powtarzalna lista: tap Path, tap Settings, tap Close, wywołanie handlera wstecz, `card_presented`, `card_resolved`, w kolejności zdefiniowanej wprost w teście, bez RNG/seed), WHEN każde zdarzenie z tej sekwencji jest przetworzone, THEN po każdym kroku dokładnie jedna z trzech par jest prawdziwa: (a) `coordination_state == NO_OVERLAY` I `ClassPathPanel.visible == false` I `SettingsScreen.visible == false`; (b) `coordination_state == PANEL_OPEN` I dokładnie jeden z `ClassPathPanel.visible`/`SettingsScreen.visible` jest `true` (nigdy oba); (c) `coordination_state == CARD_PRESENTED`. To zastępuje poprzednią wersję tej AC — sprawdza rzeczywistą zgodność stanu z widocznością, nie tylko że enum ma jakąkolwiek z 3 wartości (co i tak jest niemożliwe do naruszyć w typowanym GDScript).

**Edge cases:**
- GIVEN tap Path potem Settings w 1-2 klatkach, THEN przetworzone sekwencyjnie, stan końcowy `panel_open`/Settings, brak debounce.
- GIVEN tap panelu i `card_presented` w tej samej klatce, THEN stan końcowy zawsze `card_presented`.
- GIVEN gest wstecz i `card_presented` w tej samej klatce, THEN stan końcowy zawsze `card_presented` — priorytet karty wygrywa (dodane po `/design-review`).
- GIVEN `panel_open` (panel A), gest wstecz i tap panelu B w tej samej klatce, THEN stan końcowy zawsze `no_overlay` — priorytet gestu wstecz nad tapnięciem panelu (dodane po `/design-review`).
- GIVEN `panel_open` (panel A), gest wstecz, tap panelu B, i `card_presented` **wszystkie trzy w tej samej klatce** (dodane po `/design-review`, systems-designer finding — trójkolizja, poprzednio tylko wywodzona transytywnie, teraz jawna AC), THEN stan końcowy zawsze `card_presented` — priorytet karty wygrywa nad obydwoma pozostałymi jednocześnie.
- GIVEN `no_overlay`, dwa niezależne wywołania próbujące otworzyć różne panele trafiają w tę samą klatkę (dodane po `/design-review`, qa-lead finding — Edge Case bez odpowiadającej AC w poprzedniej wersji), THEN deterministyczne — ostatnie wywołanie w kolejności przetwarzania sygnałów Godota wygrywa, stan końcowy `panel_open` z dokładnie jednym panelem widocznym, nigdy oboma.
- GIVEN `card_resolved` wyemitowany, gdy `coordination_state` nie jest `CARD_PRESENTED` (dodane po `/design-review`, systems-designer finding), THEN no-op — stan i widoczność paneli pozostają niezmienione.

**Nietestowalne wobec samego tego GDD:**
- Dokładne wartości fade (120-150ms/100ms) — podane jako przybliżone zakresy w Visual/Audio Requirements, nie zablokowane liczby.
- Dokładna treść/styl confirm dialogu "Opuścić grę?" na Web — spec'owany jako wymóg zachowania (Core Rules), nie jako zablokowany tekst/wygląd.
- Wewnętrzna treść `SettingsScreen` po otwarciu — brak własnego GDD.
- Mechanizm przechwytywania "wstecz" na Web — niezweryfikowany technicznie (web-export spike w backlogu), patrz Engine Notes przy Regule 6. (Confirm-dialog UX warstwa jest testowalna niezależnie — patrz AC powyżej.)
- Mechanizm przechwytywania "wstecz" na iOS — niezweryfikowany technicznie (dodane po `/design-review`; wcześniejsze założenie "ten sam mechanizm co Android" odrzucone), patrz Engine Notes przy Regule 6.

## Open Questions

- **Mechanizm przechwytywania gestu "wstecz" na Web** — wymaga weryfikacji technicznej (`JavaScriptBridge` + `history.pushState`/`popstate` czy inna technika; prawdziwe "skonsumowanie" cofnięcia może nie być możliwe, tylko reakcja po fakcie), zależne od jeszcze niewykonanego web-export spike. **Aktualizacja po `/design-review`**: ryzyko realnej utraty sesji dla gracza jest już zmitygowane niezależnie od tego mechanizmu przez confirm "Opuścić grę?" (patrz Core Rules, "Web back-gesture confirm") — to pytanie dotyczy już tylko *jak eleganckie* będzie przechwycenie technicznie, nie *czy gracz może stracić sesję bez ostrzeżenia*. *Owner: `godot-specialist` przy architekturze, po web-export spike. Target: przed implementacją Reguły 6 dla platformy Web.*
- **Mechanizm przechwytywania gestu "wstecz" na iOS** (dodane po `/design-review`) — wcześniejsze założenie "ten sam mechanizm co Android (`NOTIFICATION_WM_GO_BACK_REQUEST`)" odrzucone jako prawdopodobnie błędne; iOS wymaga osobnej weryfikacji technicznej. *Owner: `godot-specialist` przy architekturze. Target: przed implementacją Reguły 6 dla platformy iOS.*
- **Wartości dokładne pulsu scrimu (refusal feedback)** (dodane po `/design-review`, game-designer + creative-director finding — poprzednio całkowicie otwarte pytanie bez żadnej spec'owanej reakcji; teraz zachowanie jest spec'owane w Visual/Audio Requirements jako miękki wymóg, tylko dokładne wartości czasowe/intensywności pozostają do feel-testu) — czas trwania i intensywność pulsu scrimu wymagają feel-testu przed finalnym zatwierdzeniem liczb, ale sam wymóg istnienia tej reakcji nie jest już otwarty. *Owner: nieprzypisany. Target: po pierwszym playteście Reguły 5/6.*
- **Utrata kontekstu panelu przy przerwaniu przez kartę** (dodane po `/design-review`, game-designer + systems-designer finding) — Reguła 5/7 celowo nie przywraca panelu po `card_resolved` (zawsze → `no_overlay`), co jest świadomym uproszczeniem (brak nav-stacka), nie błędem — ale nigdzie wcześniej nie było to nazwane jako tradeoff. **Zweryfikowane w kodzie po `/design-review`**: to utrata kontekstu UI, nie utrata danych — `SettingsScreen` commituje każdą zmianę natychmiast (patrz Reguła 7), więc żadna niezapisana zmiana nie ginie, tylko miejsce w interfejsie. Jeśli playtesty pokażą, że gracze gubią kontekst (np. wracali do Ustawień w połowie zmiany), rozważyć przywracanie panelu jako przyszłą rewizję Reguły 7. *Owner: nieprzypisany. Target: po pierwszym playteście.*
- **Ustawienie projektu "Quit On Go Back" na Androidzie** (dodane po `/design-review`, godot-specialist finding) — musi zostać jawnie wyłączone (`false`) w exporcie Android, inaczej system operacyjny może zamykać aplikację na geście wstecz niezależnie od wewnętrznego handlera tego GDD (patrz Engine Notes przy Regule 6). *Owner: `godot-specialist` / engine-programmer przy konfiguracji exportu. Target: przed pierwszym testem na fizycznym urządzeniu Android.*
- **Możliwy wciąż-otwarty bug silnika: podwójna emisja `NOTIFICATION_WM_GO_BACK_REQUEST`** (dodane po `/design-review`, godot-specialist finding, godotengine/godot#105324, niepotwierdzony dla 4.6.3) — wart smoke-testu przy pierwszej implementacji Reguły 6 na Androidzie, nie blokuje designu. *Owner: nieprzypisany. Target: pierwszy smoke-test Reguły 6 na Androidzie.*
- **Dokładne wartości fade** (dziś: przybliżone zakresy 120-150ms/100ms w Visual/Audio Requirements) — do zablokowania w `/ux-design`, jeśli powstanie UX spec dla jednego z istniejących ekranów. *Owner: nieprzypisany. Target: Pre-Production.*
- *(Poza zakresem tego GDD, znalezione przy okazji)*: `offline-report-screen.md`'s sekcja Audio (stinger/tick/thud) jest nieaktualna po decyzji o trwałym braku audio (2026-07-12) — wymaga osobnej korekty. *Owner: rewizja `offline-report-screen.md`. Target: nieprzypisany.*
