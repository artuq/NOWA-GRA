# King of Cringe — pakiet dla kolegi (design + balans + przegląd ogólny)

> Ten plik to skompresowany przegląd projektu: koncept, design wszystkich systemów (GDD), kierunek wizualny, znane luki/kompromisy i najnowsza retrospektywa z realnych testów. Składa się z istniejących dokumentów projektu (`README.md`, `design/gdd/*.md`, `design/art/art-bible-stub.md`, `docs/tech-debt-register.md`, `production/retrospectives/`), połączonych w jeden plik do łatwego czytania.
>
> **Jak czytać**: zacznij od Spisu Treści → README → Game Concept → Systems Index, potem GDD-y w kolejności (fundament → core → prezentacja). Tech Debt i Retrospektywa na koniec dają "co już wiemy, nie trzeba zgłaszać".

---

## Spis treści

1. [README — przegląd repo](#1-readme--przegląd-repo)
2. [Game Concept — fundament, pillars, MVP](#2-game-concept--fundament-pillars-mvp)
3. [Systems Index — mapa wszystkich systemów](#3-systems-index--mapa-wszystkich-systemów)
4. [GDD: Resource System](#4-gdd-resource-system)
5. [GDD: History Flag System](#5-gdd-history-flag-system)
6. [GDD: Save/Persistence System](#6-gdd-savepersistence-system)
7. [GDD: Card Content Database](#7-gdd-card-content-database)
8. [GDD: Action System](#8-gdd-action-system)
9. [GDD: Decision Card System](#9-gdd-decision-card-system)
10. [GDD: Offline Progress System](#10-gdd-offline-progress-system)
11. [GDD: Onboarding/Tutorial](#11-gdd-onboardingtutorial)
12. [GDD: Action UI](#12-gdd-action-ui)
13. [GDD: Card UI](#13-gdd-card-ui)
14. [GDD: Offline Report Screen](#14-gdd-offline-report-screen)
15. [GDD: Juice/Feedback System](#15-gdd-juicefeedback-system)
16. [Art Bible Stub — kierunek wizualny](#16-art-bible-stub--kierunek-wizualny)
17. [Tech Debt Register — znane luki/kompromisy](#17-tech-debt-register--znane-lukikompromisy)
18. [Retrospektywa Sprint 6 — najnowsze wnioski z testów](#18-retrospektywa-sprint-6--najnowsze-wnioski-z-testów)

---

## 1. README — przegląd repo

# NOWA GRA! — Król Cringe'u

## Opis projektu

„NOWA GRA!" to projekt mobilnej gry idle/incremental tycoon z narracyjnymi kartami decyzji.
Gracz buduje imperium contentowe od małego pubu do internetowej marki, a decyzje moralne wpływają na jego rozwój jako influencera.

Projekt opiera się na mechanice „select-and-wait", w której gracz wybiera działania trwające w czasie, zamiast powtarzalnie klikać. **Offline progress jest traktowany jako pierwszy priorytet** — gra symuluje postęp nawet gdy gracz nie gra, z czytelnym raportem do przejrzenia. Satyra ma być wyrażana poprzez mechanikę i konsekwencje wyborów, a nie przez moralizujące komunikaty.

## Główne założenia (4 Pillary)

1. **Uczciwa matematyka, nieuczciwy świat** — rdzenne obliczenia są przewidywalne; chaos i hazard żyją w systemach wokół gracza (sponsorzy, eventy, karty)
2. **Decyzje mają pamięć, nie punkty** — karty decyzji moralnych kumulują się w historię (flagi), która determinuje ścieżki klas
3. **Satyra przez mechanikę, nie wykład** — krytyka patologii internetu ujawnia się przez to, co gra nagradza i karze
4. **Offline jest pierwszą klasą obywatelską** — progresja offline musi być satysfakcjonująca i czytelna jak aktywna sesja

## Technologie i narzędzia

- **silnik**: Godot 4.6.3
- **język**: GDScript
- **testing**: GDUnit4
- **CI/CD**: GitHub Actions

## Obecny status

Projekt ma **kompletne MVP** (9/9 systemów core/foundation zbudowanych i przetestowanych) — pętla gry: boot → onboarding → akcje + karty decyzji → offline progress → save/restore działa end-to-end. Pełna lista systemów i ich stan: patrz Systems Index w sekcji 3 (uwaga: ten dokument odzwierciedla stan z fazy projektowej — od tego czasu wszystkie 11 systemów MVP zostały zaimplementowane w kodzie, nie tylko zaprojektowane).

---

## 2. Game Concept — fundament, pillars, MVP

# Game Concept: Król Cringe'u

## Elevator Pitch

> To jest idle/incremental tycoon, w którym budujesz imperium contentowe od pustego pubu do internetowej celebryckiej marki — a satyryczne karty decyzji moralnych w stylu "Reigns" kierują Cię na ścieżki patoinfluencingu albo czystszej sławy, podczas gdy gra uczciwie liczy Twój postęp nawet offline.

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Idle/Incremental Tycoon + narrative decision cards |
| **Platform** | Mobile (Android, docelowo iOS) |
| **Target Audience** | Fani Melvor Idle / Idle Research, którzy chcą głębi systemowej z satyrycznym tematem |
| **Player Count** | Single-player |
| **Session Length** | 5-20 min aktywnej sesji, długie okresy offline |
| **Monetization** | Niezdecydowane jeszcze (premium / F2P bez agresywnych mikropłatności — temat satyry na hazard wyklucza p2w loot boxy) |
| **Estimated Scope** | Medium (2-4 months, solo, po MVP 2-4 tygodnie) |
| **Comparable Titles** | Beggar's Life, Melvor Idle, Idle Research: Endless Tycoon |

## Core Fantasy

"Jestem twórcą internetowym budującym własne imperium contentowe — i widzę, krok po kroku, jak system (Algorytm, sponsorzy, hejterzy) kształtuje kim się stałem." Gracz dostaje satysfakcję optymalizatora (czysta matematyka progresji jak w Melvor), ale każda decyzja moralna ma realną wagę w tym, jaką ścieżką "celebryty" się stanie.

## Unique Hook

To jest jak Melvor Idle, AND ALSO każda karta decyzji moralnej (jak w Reigns) nieodwracalnie kieruje Cię na satyryczną ścieżkę klasy — Guru-Celebrytę albo Pato-Streamera Hazardowego — bez wykładu, tylko przez to co gra nagradza i karze.

## Player Experience Analysis (MDA Framework)

### Target Aesthetics

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** | 4 | Czytelny feedback przy zakończeniu cyklu akcji (efekty, dźwięk, krótka wibracja) |
| **Fantasy** | 2 | Bycie internetowym twórcą budującym własną markę |
| **Narrative** | 3 | Karty decyzji moralnych kumulujące się w historię |
| **Challenge** | 3 | Optymalizacja zespołu/sponsorów/zasobów |
| **Fellowship** | N/A | Brak multiplayer |
| **Discovery** | 5 | Odkrywanie ścieżek klas i konsekwencji wyborów |
| **Expression** | 1 | Budowanie własnej persony/marki — kosmetyczna personalizacja widoczna na ekranie głównym |
| **Submission** | 6 | Pasywna obserwacja postępu offline |

### Key Dynamics

- Gracz zacznie rozpoznawać wzorce hazardowe/toksyczne w systemie sponsorów i kartach, zamiast dostawać o tym wykład.
- Gracz będzie wracał sprawdzić raport offline, traktując go jak "wynik nocnej zmiany" swojego zespołu.
- Gracz będzie ważył krótkoterminowy zysk zasięgów vs długoterminową reputację przy każdej karcie decyzji.

### Core Mechanics

1. Wybór akcji trwającej w czasie (Nagraj vloga / Zrób dramę / Przeproś w internecie) — uruchamiana, nie tapowana w kółko.
2. Karty decyzji moralnych jako generator zasobów i bramki do ścieżek klas (historia flagowana, nie prosty licznik).
3. Offline progress liczony z delty czasu, z czytelnym raportem po powrocie.
4. Zespół (trolle/asystenci/sponsorzy) jako warstwa zarządzania zasobami zwiększająca tempo offline.
5. Kosmetyczna personalizacja persony jako warstwa Expression, odłączona od liczb.

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Karty decyzji + wybór ścieżki klasy to realne rozdroża projektowe | Core |
| **Competence** | Czyste skalowanie liczb i optymalizacja zespołu/sponsorów | Core |
| **Relatedness** | Słaba z natury (solo idle), ale satyra tworzy więź z tematem społecznym | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — optymalizacja zasobów, odblokowywanie ścieżek klas i checkpointów prestige
- [x] **Explorers** — odkrywanie konsekwencji wyborów i ukrytych ścieżek klas
- [ ] **Socializers** — brak komponentu społecznego w MVP
- [ ] **Killers/Competitors** — brak PvP/leaderboardów w MVP

### Flow State Design

- **Onboarding curve**: Pierwsze 3 akcje podstawowe są proste i bez kart decyzji — gracz uczy się pętli select-and-wait przed wprowadzeniem moralnej złożoności.
- **Difficulty scaling**: Rosnąca liczba zasobów i sponsorów wymaga coraz precyzyjniejszej alokacji zespołu.
- **Feedback clarity**: Raport offline i progress bar akcji dają jasny, czytelny sygnał postępu.
- **Recovery from failure**: Brak punktowych porażek — złe decyzje karne są odroczone (Morale/Reputacja), nigdy nie blokują gry na stałe.

## Core Loop

### Moment-to-Moment (30 seconds)
Gracz wybiera akcję z listy (Nagraj vloga / Zrób dramę / Przeproś w internecie). Akcja trwa zadany czas (sekundy do minut), widoczny jako progress bar. Brak powtarzalnego tapowania — model select-and-wait jak w Melvor Idle. "Soczystość" (efekty/dźwięk/wibracja) skupiona na zakończeniu cyklu, nie na każdym tapie.

### Short-Term (5-15 minutes)
Po zakończeniu kilku cykli akcji gracz przekracza próg zasobów i wyskakuje karta decyzji moralnej. Wybór kieruje na ścieżkę klasy i modyfikuje tempo przyszłego zysku/reputacji. Gracz wraca do wyboru akcji z nowym multiplikatorem.

### Session-Level (30-120 minutes)
Sesja = zbudowanie kolejnego piętra imperium (nowy pracownik/sponsor/budynek) + 2-3 karty decyzji + sprawdzenie raportu offline z poprzedniego zamknięcia gry. Naturalny stop po rozliczeniu offline i jednej karcie decyzyjnej.

### Long-Term Progression
Gracz odblokowuje kolejne "klasy" influencera (ścieżki zdeterminowane historią flag z kart decyzji), rozbudowuje zespół/sponsorów, i dociera do satyrycznych checkpointów (np. "wypalenie", "imperium medialne") działających jak prestige/reset w idle — gra nie ma hard-stopu, checkpointy otwierają nowy sezon z metaprogresją.

### Retention Hooks
- **Curiosity**: Jakie ścieżki klas i zakończenia satyryczne jeszcze nie zostały odkryte.
- **Investment**: Wybudowany zespół/sponsorzy i historia decyzji, których gracz nie chce "stracić" resetując.
- **Social**: Brak w MVP (poza tematycznym rezonansem satyry).
- **Mastery**: Optymalizacja alokacji zespołu i tempa offline.

## Game Pillars

### Pillar 1: Uczciwa matematyka, nieuczciwy świat
Tap/wybór akcji i progresja liczbowa są zawsze przewidywalne i sprawiedliwe; chaos i hazard żyją tylko w systemach wokół gracza (sponsorzy, eventy, karty).

*Design test*: Debata o nowej mechanice losowości w core akcji → odrzucamy, bo złamałoby to fundament "fair core, unfair world".

### Pillar 2: Decyzje mają pamięć, nie punkty
Karty decyzji moralnych kumulują się w historię (flagi), która determinuje dostępne ścieżki klas — nie prosty licznik "dobry/zły".

*Design test*: Debata między prostym moral-meterem a systemem flagów historii → wybieramy flagi/historię, bo wzmacnia satyrę i regrywalność.

### Pillar 3: Satyra przez mechanikę, nie przez wykład
Krytyka patologii internetu (hazard, patoinfluencing, dopamina) ujawnia się przez to, co gra nagradza i karze, nigdy przez tekst moralizujący.

*Design test*: Pomysł na pop-up "fakt edukacyjny" → odrzucamy, zastępujemy mechaniką (np. widoczny koszt w Morale).

### Pillar 4: Offline jest pierwszą klasą obywatelską
Postęp offline musi być tak satysfakcjonujący i czytelny jak aktywna sesja — naprawia główną wadę Beggar's Life.

*Design test*: Debata, czy nowa funkcja wymaga aktywnej obecności → domyślnie projektujemy ją tak, by działała też offline.

### Anti-Pillars (What This Game Is NOT)

- **NOT multiplayer/PvP**: złamałoby Pillar 4 (solo idle + offline) i rozdmuchało scope poza "tygodnie".
- **NOT personalizacja wizualna jako mechanika numeryczna**: rozmywa Pillar 1 — kosmetyka zostaje kosmetyką, nie wpływa na liczby.
- **NOT explicit moral score/HUD**: złamałoby Pillar 3 — gra nie mówi graczowi "jesteś złym influencerem" tekstem, tylko mechaniką.

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Melvor Idle | Model select-and-wait (wybierz akcję, ona biegnie automatycznie), czysta matematyka progresji | Dodajemy satyryczne karty decyzji jako bramki do ścieżek klas | Potwierdza, że głębia systemowa + prosty art działa na mobile |
| Beggar's Life | Drzewko klas zależne od wyborów, abstrakcyjne zasoby (wina/wdzięczność) | Naprawiamy przeładowane UI i nadmiar aktywnego klikania; mocna matematyka offline | Pokazuje potencjał tematu "od zera do imperium", ale ostrzega przed błędami UX |
| Idle Research: Endless Tycoon | Tycoon-style skalowanie liczb, automatyczne generowanie w czasie | Wprowadzamy narracyjną warstwę satyryczną zamiast czysto abstrakcyjnego tematu | Potwierdza apetyt rynku na tycoon-idle z głębokimi systemami |

**Non-game inspirations**: Kultura patoinfluencerów i internetowych "callout" kryzysów, mechaniki hazardowe w grach free-to-play (loot boxy, "kasyno sponsorów"), formaty kart decyzji w stylu Reigns.

### Reference Game Findings (2026-06-20)

Zastosowano jednolitą listę pytań playtestowych (`production/playtests/playtest-question-guide.md`) do nagrań z 4 gier referencyjnych, mimo że pytania były pisane pod mechanikę naszej gry (swipe + karty). Wynik: tylko Reigns dostał werdykt PROCEED — pozostałe trzy dostały PIVOT, bo mechanicznie/tematycznie nie pokrywają się z naszą grą.

| Reference | Verdict na nasze pytania | Co realnie potwierdza/zmienia w naszym projekcie |
|---|---|---|
| **Reigns** | PROCEED | Najbliższy mechanicznie i tonalnie. Potwierdza fundament: swipe + narracyjny payoff działa, onboarding przez sam gest (brak tutoriala), brak potrzeby precyzyjnego dotyku. **Nowy wniosek**: Reigns ma stałe napięcie 4 wskaźników frakcji przez całą rozgrywkę z realną stawką (śmierć władcy) — u nas Cringe/Morale/Hatersi robią coś podobnego, ale **nie mamy zdefiniowanej realnej stawki "przegranej"/zakończenia ery**, analogicznej do śmierci władcy. Otwarte pytanie do rozważenia przy projektowaniu Prestige/Checkpoint System (Alpha tier). |
| **Melvor Idle** | PIVOT (mechanicznie/tematycznie niezgodny) | Number-go-up + zablokowane sloty **działają jako hook niezależnie od tematu** — potwierdza decyzję o lockowanych Action Grid slotach. **Ostrzeżenie**: gęstość UI tej gry byłaby blokerem na dotyku — potwierdza naszą decyzję o oszczędnym UI (3 akcje, nie dziesiątki zakładek). |
| **Idle Research: Endless Tycoon** | PIVOT (mechanicznie/tematycznie niezgodny) | Potwierdza number-go-up jako solidny, niezależny hook. **Ostrzeżenie**: przy bardzo dużych liczbach (e50, e100) recenzent zgłosił, że liczby zmieniają się w "szum w tle", nieczytelny postęp — flaguje potrzebę monitorowania, czy nasz K/M format (`action_ui_number_format`) wystarcza na długą rozgrywkę, czy potrzeba dalszych jednostek (M, potem co?). |
| **Beggar's Life** | PIVOT (tematycznie niezgodny — to symulator bezdomności, nie satyra na influencerów) | Ton "mozolnego, przytłaczającego" postępu (nie triumfalnego) jest bliżej naszej satyry niż heroiczna fantazja Melvora — wzmacnia decyzję, że King of Cringe nie powinien czuć się jak czyste heroiczne wbijanie poziomów. Mechanizm "chcę zobaczyć jak źle/absurdalnie to się potoczy" zadziałał tam dobrze — to ten sam mechanizm, na którym stoi nasza eskalacja Cringe; potwierdza potencjał, warunkowany dobrym pisaniem treści kart. |

**Metodologiczny wniosek na przyszłość**: przy kolejnych badaniach referencyjnych, jeśli gry referencyjne różnią się mechanicznie (nie wszystkie mają karty/swipe), warto przygotować pytania uniwersalne na poziomie *hooka* (np. "czy chciałeś zrobić jeszcze jedno", nie "czy karta Cię zaskoczyła") — część pytań z tej rundy nie miała zastosowania do 3 z 4 gier i dała odpowiedzi typu "to pytanie nie ma zastosowania", co jest poprawne, ale mniej informacyjne niż mogłoby być.

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18-35 |
| **Gaming experience** | Mid-core (komfortowi z systemami liczbowymi, ale na mobile, sesyjnie) |
| **Time availability** | Krótkie sesje 5-20 min, kilka razy dziennie + długie okresy offline |
| **Platform preference** | Android (docelowo iOS) |
| **Current games they play** | Melvor Idle, Idle Research: Endless Tycoon, Beggar's Life |
| **What they're looking for** | Głęboką progresję numeryczną z czytelnym, satyrycznym tematem — coś więcej niż kolejny generyczny clicker |
| **What would turn them away** | Przeładowane UI, nadmiar aktywnego klikania, moralizujące wykłady zamiast satyry przez mechanikę |

## Risks and Open Questions

### Design Risks
- Satyra może nie być odczytana jako satyra — gracz po prostu optymalizuje liczby bez refleksji nad tematem.
- Model select-and-wait może czuć się "zbyt pasywny" bez wystarczająco częstych kart decyzji do aktywnego zaangażowania.

### Market Risks
- Segment idle/incremental jest zatłoczony — temat satyryczny musi być widoczny już w pierwszych ekranach store'u, by się wyróżnić.

### Open Questions
- Jak dokładnie system flagów historii determinuje dostępność ścieżek klas? — wymaga prototypu/dokumentu systemowego.
- Jaki jest model monetyzacji, który nie zaprzecza satyrze na hazard? — do rozstrzygnięcia przed `/design-system` ekonomii.
- **Czy potrzebujemy "realnej stawki" analogicznej do śmierci władcy w Reigns?** (z Reference Game Findings, 2026-06-20) — gra ma świadomą decyzję anty-porażkową (konsekwencje odroczone, nigdy blokujące na stałe), ale Reigns pokazuje, że ciągłe napięcie 4 wskaźników z realną stawką jest mocnym hookiem. Nie chcemy kopiować permadeath, ale **Prestige/Checkpoint System (Alpha tier)** może być naturalnym miejscem na "koniec ery"/transformację bez game-over.

## MVP Definition

**Core hypothesis**: Gracze uznają pętlę "wybierz akcję trwającą w czasie + karty decyzji moralnych kierujące ścieżką klasy + czytelny raport offline" za satysfakcjonującą bez potrzeby aktywnego tapowania.

**Required for MVP**:
1. 3 akcje podstawowe (Nagraj vloga / Zrób dramę / Przeproś w internecie) działające w modelu select-and-wait
2. System offline progress z deltą czasu i czytelnym raportem powrotu
3. 10-15 kart decyzji moralnych z systemem flag historii prowadzącym do 2 ścieżek klas

**Explicitly NOT in MVP**:
- Personalizacja wizualna persony (kosmetyka)
- System sponsorów jako rozwinięte "kasyno" satyryczne
- Trzecie i dalsze zakończenia-checkpointy / prestige

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 3 akcje, 10-15 kart, 2 ścieżki klas | Select-and-wait loop, offline math, flagi historii | 2-4 tygodnie |
| **Vertical Slice** | + 1 system sponsorów, 1 checkpoint prestige | + kosmetyczna personalizacja podstawowa | 4-6 tygodni |
| **Alpha** | 4 ścieżki klas, 25+ kart | Wszystkie systemy, rough polish | 2-3 miesiące |
| **Full Vision** | 4+ ścieżki klas, 40+ kart, 3 zakończenia-checkpointy | Pełna wizualna progresja, dopracowane "kasyno" sponsorów | 2-4 miesiące |

---

## 3. Systems Index — mapa wszystkich systemów

# Systems Index: Król Cringe'u

## Overview

Król Cringe'u jest idle/incremental tycoonem na mobile, gdzie gracz wybiera akcje trwające w czasie (select-and-wait, jak Melvor Idle), zamiast tapować w kółko. Karty decyzji moralnych (styl Reigns) generują zasoby i kumulują historię w postaci flag, które otwierają satyryczne ścieżki klas influencera. Cała architektura mechaniczna stoi na czterech pillarach: uczciwa matematyka rdzenia (Pillar 1), decyzje-jako-pamięć (Pillar 2), satyra przez mechanikę nie wykład (Pillar 3) i offline jako pierwsza klasa obywatelska (Pillar 4).

## Systems Enumeration

> **Uwaga**: kolumna "Status" poniżej pochodzi z dokumentu projektowego (fazy designu) — od jej napisania wszystkie 11 systemów MVP zostały w pełni zaimplementowane i przetestowane w kodzie (Godot/GDScript), nie tylko zaprojektowane.

| # | System Name | Category | Priority | Status (design-doc) | Depends On |
|---|-------------|----------|----------|--------|------------|
| 1 | Resource System | Economy | MVP | Designed → **Zbudowany** | — |
| 2 | History Flag System | Narrative | MVP | Designed → **Zbudowany** | — |
| 3 | Save/Persistence System | Persistence | MVP | Designed → **Zbudowany** | — |
| 4 | Card Content Database | Narrative | MVP | Designed → **Zbudowany** | — |
| 5 | Action System | Gameplay | MVP | Designed → **Zbudowany** | Resource System |
| 6 | Decision Card System | Narrative | MVP | Designed → **Zbudowany** | Card Content Database, History Flag System, Resource System |
| 7 | Offline Progress System | Core | MVP | Designed → **Zbudowany** | Resource System, Save/Persistence System |
| 8 | Action UI | UI | MVP | Designed → **Zbudowany** | Action System |
| 9 | Card UI | UI | MVP | Designed → **Zbudowany** | Decision Card System |
| 10 | Offline Report Screen | UI | MVP | Designed → **Zbudowany** | Offline Progress System |
| 11 | Onboarding/Tutorial | Meta | MVP | Designed → **Zbudowany** | Action System, Decision Card System |
| 12 | Class Path System | Progression | Vertical Slice | Not Started | History Flag System, Decision Card System |
| 13 | Juice/Feedback System | Audio | Vertical Slice | Designed (częściowo wdrożony — resolution beat w kartach) | Action System, Decision Card System |
| 14 | Main Navigation/Screen Flow | UI | Vertical Slice | Not Started | Action UI, Card UI, Offline Report Screen |
| 15 | Team/Staff Management | Economy | Alpha | Not Started | Resource System, Offline Progress System |
| 16 | Staff/Sponsor UI | UI | Alpha | Not Started | Team/Staff Management |
| 17 | Prestige/Checkpoint System | Progression | Alpha | Not Started | Class Path System, Offline Progress System, Save/Persistence System |
| 18 | Cosmetic Persona Customization | UI | Full Vision | Not Started | Class Path System |

## Dependency Map

### Foundation Layer (no dependencies)
1. Resource System — base currencies (Cringe, Reach, Haters, Morale, Sponsors); everything else reads/writes these
2. History Flag System — pure data structure recording decision history
3. Save/Persistence System — serialization infrastructure
4. Card Content Database — static content data (12 cards)

### Core Layer (depends on foundation)
1. Action System — depends on: Resource System
2. Decision Card System — depends on: Card Content Database, History Flag System, Resource System
3. Offline Progress System — depends on: Resource System, Save/Persistence System

### Feature Layer (depends on core)
1. Class Path System — depends on: History Flag System, Decision Card System
2. Team/Staff Management — depends on: Resource System, Offline Progress System
3. Prestige/Checkpoint System — depends on: Class Path System, Offline Progress System, Save/Persistence System

### Presentation Layer (depends on features)
1. Action UI — depends on: Action System
2. Card UI — depends on: Decision Card System
3. Offline Report Screen — depends on: Offline Progress System
4. Staff/Sponsor UI — depends on: Team/Staff Management
5. Cosmetic Persona Customization — depends on: Class Path System
6. Main Navigation/Screen Flow — depends on: Action UI, Card UI, Offline Report Screen
7. Juice/Feedback System — depends on: Action System, Decision Card System

### Polish Layer
1. Onboarding/Tutorial — depends on: Action System, Decision Card System

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Resource System | Scope | Bottleneck — wszystko zależy od niego. Błąd projektowy tutaj kaskaduje do wszystkich innych systemów. | Zaprojektowany i zablokowany pierwszy |
| History Flag System | Design | Bottleneck dla satyrycznej narracji (Pillar 2) | Zaprojektowany z jasną tabelą flag→ścieżka |
| Offline Progress System | Technical | Core hipoteza MVP ("offline jest satysfakcjonujące") | Zweryfikowane w izolacji przed pełnym GDD |
| Decision Card System | Design | **Satyra może nie być odczytana jako satyra** — gracze mogą po prostu optymalizować liczby bez zauważenia krytyki | Playtest wczesnych draftów kart specjalnie pod kątem czy testerzy zauważają satyryczną intencję |

---

## 4. GDD: Resource System

# Resource System

> **Implements Pillar**: Pillar 1 — Uczciwa matematyka, nieuczciwy świat

## Overview

Resource System to warstwa danych definiująca wszystkie zasoby gry — Zasięgi, Cringe, Hatersi, Morale, Sponsorzy — oraz reguły ich przepływu między systemami. Dla gracza to bezpośrednio odczuwalny rdzeń satysfakcji: każda liczba na ekranie rośnie w sposób przewidywalny i uczciwy (Pillar 1).

## Player Fantasy

Gracz bezpośrednio widzi i rozumie każdy zasób — to namacalna, czytelna nagroda za każdą akcję. Satyryczny twist: Cringe i Hatersi — zasoby, które brzmią negatywnie — same w sobie też muszą "się opłacać" rosnąć, co zaczyna budować w graczu pierwsze wątpliwości moralne, zanim jeszcze dotrze do kart decyzji.

## Core Rules

**Zasoby (5):**

| Code Key | Zasób (PL) | Rola | Generowany przez | Konsekwencja |
|---|---|---|---|---|
| **Reach** | Zasięgi | Główna waluta progresji | Akcje podstawowe, Hatersi (passive), Decision Cards | Brak bezpośredniej kary — "uczciwa" liczba |
| **Cringe** | Cringe | Bufor ryzyka — rośnie z ryzykownych akcji, opada wolno z bezpiecznych | Akcje, Decision Cards | Napędza tempo przyrostu Hatersów ORAZ przesuwa pulę kart decyzji w stronę ryzykownych wariantów |
| **Haters** | Hatersi | Generator darmowych Zasięgów w tle, ale drenuje Morale | Pośrednio z poziomu Cringe | Każdy Haters drenuje Morale proporcjonalnie do swojej liczby |
| **Morale** | Morale | Modyfikator efektywności wszystkich akcji | Bazowo pełne; regenerowane przez "Przeproś w internecie" | Niskie Morale = mnożnik efektywności akcji < 1.0 |
| **Sponsors** | Sponsorzy | Waluta ekonomii zespołu (pełna mechanika w Team/Staff Management, Alpha) | Decision Cards | Brak konsekwencji w MVP — placeholder |

**Łańcuch konsekwencji (Pillar 1 w praktyce):**

`Akcja ryzykowna → ↑Cringe → ↑tempo przyrostu Hatersów (w tle) → ↑Hatersi → ↓Morale → ↓mnożnik efektywności akcji`

Równolegle: `↑Cringe → przesunięcie puli kart decyzji w stronę ryzykownych wariantów`.

Rdzeń (nagrody z akcji) jest zawsze przewidywalny i niezmienny — to "nieuczciwy świat" (Hatersi, Morale, dobór kart) reaguje na decyzje gracza, nigdy odwrotnie.

**Morale Bands:**

| Stan Morale | Zakres | Mnożnik efektywności akcji |
|---|---|---|
| Wysokie | 70–100% | 1.0x |
| Normalne | 40–69% | 0.9x |
| Niskie | 15–39% | 0.75x |
| Krytyczne | 0–14% | 0.5x |

## Formulas

**A. Hatersi Passive Growth Rate (function of Cringe)**

`H_rate(C) = H_base + (C / 100)^H_exp × H_max_add`

Tuning: `H_base=0.02`, `H_exp=2.0`, `H_max_add=1.0` → C=10: 0.03/min; C=50: 0.27/min; C=100: 1.02/min.

**B. Morale Drain Rate (function of Hatersi count, with buffer zone)**

`M_drain(N) = M_drain_per_hater × max(0, N - N_buffer)^M_drain_exp`

Tuning: `N_buffer=3`, `M_drain_per_hater=0.15`, `M_drain_exp=1.3`. N=2 → 0%/min (free); N=10 → ~1.88%/min; N=25 → ~8.34%/min.

**C. Action Effectiveness Multiplier (Morale band lookup)**
```
Mult(M) = 1.00  if 70 ≤ M ≤ 100
        = 0.90  if 40 ≤ M < 70
        = 0.75  if 15 ≤ M < 40
        = 0.50  if  0 ≤ M < 15
```
Discrete bands, no interpolation (legible math, Pillar 1).

**D. Passive Zasięgi Income from Hatersi**

`Z_passive(N, Δt) = N × Z_per_hater × Mult(M) × (Δt / 60)`

Tuning: `Z_per_hater=0.2`. Example: N=10, M=80%→Mult=1.0, Δt=600s → 20 Zasięgi/10min.

**E. Cringe Delta from Actions**

`ΔCringe = clamp(C + Cringe_delta_action, 0, 100) - C`

Per-action delta: -15 do +20. Near ceiling, marginal Cringe gain naturally shrinks (soft brake, no explicit punishment).

## Edge Cases

- Morale=0 i Hatersi drenują dalej: ΔMorale floored at -M_current; mult stays 0.5x.
- Cringe=0 i bezpieczna akcja: brak efektu, Cringe nie idzie poniżej 0.
- Tylko jedna akcja `running` na raz — potwierdzone przez prototypy.
- Hatersi=0: Z_passive=0, drain=0 — w pełni "fair" stan startowy.
- **Degenerate strategy check** — gracz może farmić Cringe do zera i nigdy nie ryzykować. To legalna "czysta ścieżka", świadomie niekarana na poziomie Resource System.

## Tuning Knobs

| Knob | Start | Safe Range |
|---|---|---|
| `H_base` | 0.02 | 0.0–0.05 |
| `H_exp` | 2.0 | 1.5–2.5 |
| `H_max_add` | 1.0 | 0.5–2.0 |
| `N_buffer` | 3 | 2–5 |
| `M_drain_per_hater` | 0.15 | 0.05–0.3 |
| `M_drain_exp` | 1.3 | 1.1–1.6 |
| `Z_per_hater` | 0.2 | 0.1–0.5 |

---

## 5. GDD: History Flag System

# History Flag System

> **Implements Pillar**: Pillar 2 — Decyzje mają pamięć, nie punkty

## Overview

History Flag System to warstwa danych zapisująca każdą znaczącą decyzję gracza jako trwałą flagę (boolean lub licznik) w persystentnym rejestrze historii. To nie jest jeden licznik "moralności" — to zbiór dyskretnych faktów, które inne systemy odczytują, by warunkowo odblokowywać treść i ścieżki.

## Player Fantasy

Gracz nigdy nie widzi surowej listy flag jako interfejsu — ale czuje ich efekt bardzo bezpośrednio: karta decyzji za tydzień wspomina jego wcześniejszy wybór; ścieżka klasy jest konsekwencją konkretnego wzorca zachowań, nie przypadkiem. To daje poczucie "świat mnie pamięta i traktuje serio moje wybory".

## Core Rules

**Two flag types:**
1. **Milestone Flags** (boolean, one-time, immutable once set) — np. `card.exposed_friend.chosen`. Raz `true`, nigdy `false`.
2. **Pattern Counters** (integer, monotonicznie rosnące, nigdy zmniejszane) — np. `risky_choices_count`, `safe_choices_count`.

**API:**
- `set_milestone(name)` — idempotentne
- `has_milestone(name) → bool`
- `increment_counter(name, amount=1)` — amount musi być ≥0
- `get_counter(name) → int`
- `counter_above_threshold(name, threshold) → bool` — inclusive (`>=`)

**Path Resolution Algorithm:**
```
function resolve_path_eligibility(counters):
    registered_paths = [
        { path: "Pato-Streamer Hazardowy", counter: "risky_choices_count", threshold_min: 5 },
        { path: "Guru-Celebryta", counter: "safe_choices_count", threshold_min: 5 },
    ]
    margin = 2
    eligible = paths where counter >= threshold_min
    if eligible empty: return null
    highest = eligible sorted by counter descending [0]
    if only one eligible: return highest
    if highest.counter - second.counter >= margin: return highest
    else: return null  # tie — ambiguous, no path yet
```

**Worked example**: risky=6, safe=1 → "Pato-Streamer Hazardowy". risky=6, safe=5 → `null` (margin 1 < 2, ambiguous).

## Edge Cases

- Counter overflow: nieosiągalne (64-bit int).
- Remis w marginie: `resolve_path_eligibility()` zwraca `null`, nigdy losowo nie wybiera.
- Brak API do decrement/unset — historia jest strukturalnie niezmienna.

## Tuning Knobs

| Knob | Start | Safe Range |
|---|---|---|
| `margin` (tie-break) | 2 | 1–4 |
| `threshold_min` per path | 5 | 3–10 |

**Explicit non-knob**: brak parametru decay/time-weighting dla Pattern Counters — per Pillar 2, liczniki są permanentne i niewagowane.

---

## 6. GDD: Save/Persistence System

# Save/Persistence System

> **Implements Pillar**: Pillar 4 — Offline jest pierwszą klasą obywatelską

## Overview

Save/Persistence System zapisuje i odtwarza pełny stan gry między sesjami. Bez tego systemu Offline Progress System nie ma punktu odniesienia.

## Player Fantasy

Gracz nigdy nie myśli o tym systemie — i to jest cel. Jedyny moment, w którym ten system "istnieje" dla gracza, to brak frustracji: gra wraca dokładnie tak, jak ją zostawił.

## Core Rules

**Save schema (jeden plik JSON):** schema_version, last_saved_at, resources, history_flags (milestones+counters), decision_card_state, onboarding.

**Rules:**
1. Autosave po każdym znaczącym zdarzeniu (zakończenie akcji, rozwiązanie karty) — brak manualnego przycisku "Zapisz".
2. Pełny snapshot, nie różnicowy patch.
3. Loading raz, przy starcie apki.
4. `last_saved_at` jako Unix timestamp — konsumowany przez Offline Progress System.
5. **Mobile lifecycle flush**: jeśli debounced save czeka na timer gdy OS sygnalizuje backgrounding, save odpala się natychmiast.

## Edge Cases

- Dwa zdarzenia w oknie debounce (2s) → coalesced w jeden save (trailing-edge).
- Brak pliku save → defaults.
- Uszkodzony JSON → traktowany jak "brak pliku" (reset, nie crash).
- App zamknięty mid-saving → write do temp file, atomic rename — partial write nigdy nie nadpisuje poprzedniego kompletnego pliku.
- Mismatch `schema_version` → traktowany jak "brak pliku" (no migration logic w MVP).

## Tuning Knobs

| Knob | Start | Safe Range |
|---|---|---|
| `save_debounce_interval_sec` | 2 | 1–5 |

---

## 7. GDD: Card Content Database

# Card Content Database

> **Implements Pillar**: Pillar 2 / Pillar 3

## Overview

Card Content Database to schemat i zawartość kart decyzji moralnych — definicja "co to jest karta" oraz konkretna treść MVP (12 kart). To czysto danowa warstwa — logika *kiedy* karta się pojawia należy do Decision Card System.

## Player Fantasy

Karty decyzji są momentem, w którym gracz przestaje optymalizować liczby i zaczyna *wybierać kim jest jako influencer*. To satyryczny rdzeń gry.

## Core Rules

**Card schema:** id, trigger_condition, text, options (exactly 2). Każda opcja: label, resource_deltas, counter_increments, milestone_to_set (optional), resolution_reaction (optional — krótki tekst "algorithm logic report" po rozwiązaniu).

**Rules:**
1. Każda karta ma **exactly 2 options** (Reigns-style).
2. **Nie każda karta jest testem moralnym.** Risky/safe cards (jedna opcja inkrementuje `risky_choices_count`, druga `safe_choices_count`) vs. neutral cards (żadna opcja nie dotyka liczników — czysto taktyczne trade-offy).

**MVP content (12 kart: 8 risky/safe + 4 neutral):**

*Risky/Safe (8):* exposed_friend, sponsor_offer_shady, hater_callout, staged_drama, competitor_drama, leaked_dm, cancel_threat, apology_tour — każda z parą opcji A (risky, wyższe Reach + Cringe, niższe Morale) / B (safe, odwrotnie).

*Neutral (4):* fan_in_trouble, brand_deal_choice, algorithm_hack, burnout_warning — brak wpływu na liczniki risky/safe.

Risky:Safe Reach ratio: 1.4x–1.8x (3 karty wyjątkowo do 1.83x, zaakceptowane jako wyższa stawka).

**Resolution reactions** — autorowane dla wszystkich 12 kart, ton: fakt/liczba, nigdy ocena (np. "Sponsorship logged. 3 viewers asked if the product works. 0 received an answer.").

## Visual/Audio Requirements

- Każda karta: pełnoekranowy modal, rozwiązywana **gestem swipe** (lewo=A, prawo=B).
- Brak timera, brak auto-resolve.
- **Resolution feedback musi komunikować konsekwencję i wagę, nigdy ocenę moralną.** Brak kodowania kolorem dobre/złe.
- 3 karty milestone-bearing (staged_drama, cancel_threat, algorithm_hack) dostają wizualnie ciężniejszy/dłuższy beat rozwiązania — sygnalizujący **trwałość**, nie moralność.

## Edge Cases

- Karta z kosztem, gdy gracz ma mniej zasobów niż koszt — Resource System nie definiuje floor dla Zasięgi/Sponsorzy (gap, otwarte pytanie).
- Karty z `milestone_to_set` nie powinny się powtarzać po rozwiązaniu; karty bez — mogą.

---

## 8. GDD: Action System

# Action System

> **Implements Pillar**: Pillar 1

## Overview

Action System to rdzeń mechaniczny gry — implementuje pętlę **select-and-wait** (wybór akcji → trwa w czasie → nagroda po zakończeniu).

## Player Fantasy

Gracz czuje kontrolę i przewidywalność — wybiera akcję wiedząc dokładnie, co dostanie. To satysfakcja optymalizatora, nie hazardzisty.

## Core Rules

**3 base actions:**

| Action | Type | Duration | Reward table (Reach/Cringe/Morale) | Reach/s |
|---|---|---|---|---|
| Nagraj vloga | neutral | 6s | +5 / +2 / 0 | 0.83 |
| Zrób dramę | risky | 9s | +10 / +20 / -3 | 1.11 |
| Przeproś w internecie | safe | 4s | +6 / -15 / +5 | 1.50 |

**Rules:**
1. Tylko **jedna akcja na raz** może być `running`.
2. Statyczna, predefinowana reward table — brak losowości w samej akcji.
3. Finalna nagroda Reach skalowana przez **Morale multiplier** (Resource System Formula C).
4. `Zrób dramę` (risky) płaci **1.6x** Reach `Przeproś` (safe).

## Formulas

`final_zasiegi_reward = base_zasiegi × Mult(M)`

Example: Zrób dramę przy Normal Morale (M=0.90) → 10×0.9=9.0 → round-half-up → 9 Reach.

## Edge Cases

- Wybór akcji podczas `running` → odrzucony.
- Cringe=100 przy `Zrób dramę` → naturalny clamp z Resource System.
- Natychmiastowy re-select tej samej akcji po `resolved` → dozwolone, brak cooldownu.

## Tuning Knobs

| Knob | Start | Safe Range |
|---|---|---|
| Durations | 6s/9s/4s | 3s–20s |
| Per-action Reach | 5/10/6 | tied to ratio 1.4-1.8x |
| Per-action Cringe Δ | +2/+20/-15 | within ±20/-15 range |

**Ważna lekcja balansu**: oryginalny czas trwania "Zrób dramę" (12s) tworzył dominated strategy (Reach/s zrównany z neutral baseline) — naprawione na 9s. Zawsze sprawdzaj per-second rates wspólnie, nie w izolacji.

---

## 9. GDD: Decision Card System

# Decision Card System

> **Implements Pillar**: Pillar 2 / Pillar 3

## Overview

Decision Card System to logika selekcji i wagowania kart decyzji — odpowiada na "która karta powinna się teraz pojawić?" i "jak Cringe wpływa na pulę?".

## Player Fantasy

Gracz bezpośrednio doświadcza karty — to jedyny moment, gdzie czuje, że **wybiera, kim jest**, nie tylko optymalizuje liczby. Gdy gra coraz częściej proponuje ryzykowne karty, to konsekwencja jego własnej historii wyborów.

## Core Rules

**Cooldown + threshold:**
1. Po rozwiązaniu karty: cooldown 2 zakończonych akcji.
2. Po cooldownie: sprawdzane wszystkie karty z `trigger_condition=true`, niewyczerpane (milestone).
3. Z dostępnej puli: **weighted random selection**.
4. Brak kart spełniających kryteria → cooldown reset, retry na następnej akcji.

**Weighting:**

`weight(card) = base_weight + (current_Cringe / 100) × intensity(card)`

gdzie `intensity` = Cringe delta opcji ryzykownej (0 dla neutral cards). Wyższy Cringe → proporcjonalnie więcej high-intensity ryzykownych kart — ale neutralne/bezpieczne nigdy nie są wykluczone (`base_weight` zawsze >0).

**Validated at extremes:**
- Cringe=0: wszystkie karty = `base_weight=10`, uniform 8.33% każda.
- Cringe=100 (suma wag=336): staged_drama 13.4%, ..., każda neutral 3.0%. Spread ~4.5x.

## Edge Cases

- Pusta pula po filtrowaniu milestone → cooldown reset, retry.
- Wszystkie 12 kart mają `trigger_condition="always"` w MVP — filtrowanie no-op aż do przyszłych kart z progami.
- Ta sama nie-milestone karta może się powtórzyć — brak repeat-prevention (flagowane do obserwacji).

## Tuning Knobs

| Knob | Start | Safe Range |
|---|---|---|
| `base_weight` | 10 | 5–20 |
| Cooldown (akcje) | 2 | 1–5 |

**Guardrail**: przy >20 kartach (Vertical Slice/Alpha), re-walidować czy spread wag (~4.5x) nie wymaga cap/normalizacji.

---

## 10. GDD: Offline Progress System

# Offline Progress System

> **Implements Pillar**: Pillar 4

## Overview

Offline Progress System symuluje upływ czasu między sesjami: liczy `Δt`, dzieli na kroki (1 min), krokowo re-ewaluuje pasywny dochód Reach, tempo przyrostu Haters i drenaż Morale — bo wszystkie trzy zmieniają się wzajemnie w czasie.

## Player Fantasy

Gracz wraca do gry i widzi namacalny dowód, że jego imperium "żyło" bez niego. To moment "co przegapiłem?", analogiczny do sprawdzania powiadomień z social media po przerwie. Satyrycznie: to mechanizm FOMO bez kosztu.

## Core Rules

**Key simplification**: Cringe nie zmienia się offline (brak akcji/kart bez gracza) — więc tempo przyrostu Haters jest *constant*. Ale Morale i mnożnik *się* zmieniają — wymaga stepwise re-evaluation.

```
function simulate_offline(Δt, Cringe_fixed, H0, M0):
    remaining = min(Δt, MAX_OFFLINE_CAP_SECONDS)  # 86400 = 24h
    while remaining > 0:
        dt = min(60, remaining)
        H += H_rate × (dt/60)
        M_drain = ...; M = max(0, M - M_drain × (dt/60))
        Z_gained += H × Z_per_hater × Mult(M) × (dt/60)
        remaining -= dt
    return { final_H, final_M, total_Z_gained, capped }
```

**Worked example**: Cringe=50, H0=5, M0=80%, Δt=24h (capped) → final_H≈394, final_M≈0%, total_Z_gained≈28,000-29,000.

**Confirmed behavior (intencjonalne, nie bug)**: Morale crashuje przez wszystkie bandy w ~70-90 min offline dla umiarkowanego/wysokiego Cringe, potem siedzi na Critical (0.5x) ~21-22h z 24h. Zaakceptowane jako deliberate satirical/FOMO hook ("twoje imperium wypaliło się gdy nie patrzyłeś").

## Edge Cases

- Δt=0 → brak efektu.
- Δt>24h cap → tylko pierwsze 24h liczone, `capped=true`.
- Brak `last_saved_at` (pierwsza sesja) → system **nie odpala się wcale**.

## Tuning Knobs

| Knob | Start | Safe Range |
|---|---|---|
| `MAX_OFFLINE_CAP_SECONDS` | 86400 (24h) | 43200–259200 (12h–72h) |
| `OFFLINE_STEP_SECONDS` | 60 | 60 only |

## Open Questions

- **Czy 24h jest właściwym capem?** — nie zwalidowane realnymi danymi graczy.
- **Czy offline Morale spiral potrzebuje walidacji playtestem?** — zaakceptowane jako intencjonalny hook, ale to założenie projektowe niepotwierdzone graniem.

---

## 11. GDD: Onboarding/Tutorial

# Onboarding/Tutorial

> **Implements Pillar**: 1, 2, 3, 4 — pierwsze wrażenie gracza

## Overview

Onboarding/Tutorial rozkłada w czasie ekspozycję na 3 akcje podstawowe, pierwszą kartę decyzji i pierwszy powrót offline — by gracz nie był zalany złożonością. Nie tworzy nowej logiki — definiuje **kolejność i tempo** odsłaniania.

## Player Fantasy

Gracz czuje, że gra "rozumie", że jest nowy — pierwsze minuty są proste, bez presji moralnej, zanim zrozumie podstawową pętlę. To nie tutorial-jako-wykład — gra uczy przez strukturę doświadczenia.

## Core Rules

**Sequencing:**
1. **Phase 1 — Pure action (variety-gated, NOT count-gated):** Decision Card System suppressed aż gracz wypróbuje **co najmniej jeden z każdego z 3 typów akcji** — nie po prostu "3 akcje" (3 powtórzenia tego samego nigdy nie pokażą pełnej reward table).
2. **Phase 2 — First card:** po wypróbowaniu wszystkich 3 typów, cooldown Decision Card System resetowany do 0 — pierwsza karta po następnej akcji (min. 4ta ogółem).
3. **Phase 3 — Normal play:** od tego momentu Decision Card System działa autonomicznie.
4. Resource System i History Flag System **nigdy nie są gated** — onboarding kontroluje tylko widoczność kart.

**Timing sanity check**: 3 akcje (jedna z każdego typu) zajmują ~12-27s — komfortowo w normalnych oknach onboardingowych na mobile.

## Edge Cases

- App zamknięty w `phase_pure_action` → resume z dokładnego punktu, nigdy reset.
- `phase_first_card_pending` + zamknięcie → cooldown=0 musi przetrwać save/load.
- Reinstall (brak save) → onboarding od zera.
- 3 typy w nienaturalnej kolejności → transition fires after 3rd distinct type regardless of order.

## Tuning Knobs

| Knob | Start | Safe Range |
|---|---|---|
| Required action types before first card | All 3 | 1–3 (locked design decision, nie tuning) |
| Cooldown override at Phase 1→2 | 0 | 0 only |

---

## 12. GDD: Action UI

# Action UI

> **Implements Pillar**: Pillar 1

## Overview

Action UI to ekran główny gry — implementacja wymagań z Action System: 3 zawsze widoczne przyciski akcji, progress bar, layout zarezerwowany na 3 przyszłe akcje.

## Player Fantasy

Gracz dotyka ekranu i czuje, że dzieje się coś realnego — duży, responsywny przycisk, czytelny czas trwania, jasna nagroda.

## Core Rules

**Layout (3 zony):**
1. **Resource HUD** (top) — wszystkie 5 zasobów real-time. Morale jako band (High/Normal/Low/Critical), nie raw %.
2. **Action Grid** (middle) — 6 slotów: 3 unlocked + 3 locked (🔒).
3. **Running Action Overlay** — gdy akcja `running`, cały grid disabled, progress bar z nazwą i czasem.

**Rules:**
1. Wszystkie 6 slotów zawsze widoczne — layout nigdy nie reflow'uje przy unlocku.
2. Tap unlocked przy `idle` → wybór do Action System. Tap locked/podczas `running` → no-op.
3. Progress bar update co frame, nie co sekundę.

## Formulas

**Large-number formatting (K/M):**

| Range | Format | Example |
|---|---|---|
| < 1,000 | Plain integer | `847` |
| 1,000–999,999 | `X.XK` | `28,412 → "28.4K"` |
| ≥ 1,000,000 | `X.XM` | `1,250,000 → "1.2M"` |

**Rounding rule (skorygowane)**: **truncate**, nigdy round — bo `999,999 → "999.9K"` i hard boundary przy 1M wymagają truncation, nie round-half-up.

## Visual/Audio Requirements

- Każdy zasób ma własny hue, **niezależny od tego czy jest tematycznie "dobry" czy "zły"** (Cringe/Hatersi nie są kodowane czerwono).
- Locked sloty wizualnie wytłumione (niższy kontrast), nigdy ukryte.
- Completion "soczystość" skaluje się z czasem trwania akcji, nigdy nie koduje dobre/złe.

---

## 13. GDD: Card UI

# Card UI

> **Implements Pillar**: Pillar 3

## Overview

Card UI to ekran prezentacji kart decyzji — scala wymagania z Card Content Database (swipe, ikony) i Decision Card System (uniform entrance, blokowanie UI).

## Player Fantasy

Gracz czyta sytuację, czuje wagę wyboru pod palcem podczas swipe — najbardziej fizyczny, namacalny moment w grze.

## Core Rules

**Modal layout:**
1. Ikona kategorii + tekst sytuacji, centered.
2. Obie etykiety opcji widoczne bez dragowania.
3. Karta blokuje Resource HUD i Action Grid pod sobą.

**Swipe mechanics:**
1. **Drag preview**: karta śledzi palec 1:1, z lekkim tiltem.
2. **Commitment threshold = 30% szerokości ekranu** (lub flick velocity ≥800px/s).
3. Podczas dragowania, etykieta w kierunku gestu lekko się powiększa, druga przygasa — czysto interaktywny feedback, nie moralne kodowanie.

## Formulas

**Drag rotation:**

`rotation_degrees = clamp(drag_x / half_screen_width, -1.0, 1.0) × max_tilt_degrees` (max 12°)

**Commitment check (distance OR velocity, Tinder-style):**

`is_committed = (abs(drag_x_at_release) >= 0.30 × screen_width) OR (abs(velocity) >= 800px/s)`

## Edge Cases

- Tap bez dragowania → `is_committed=false` → bounce-back, brak alternative tap-resolve.
- Multitouch → tylko pierwszy dotyk tracked, drugi ignorowany.
- Przerwanie gestu (np. telefon w tle) → reset natychmiastowy, bez animacji.

## Tuning Knobs

| Knob | Start | Safe Range |
|---|---|---|
| `commit_threshold_ratio` | 0.30 | 0.20–0.50 |
| `flick_velocity_threshold` | 800 px/s | 500–1200 px/s |
| `max_tilt_degrees` | 12° | 8–15° |

---

## 14. GDD: Offline Report Screen

# Offline Report Screen

> **Implements Pillar**: Pillar 4

## Overview

Offline Report Screen wyświetla wynik symulacji offline — `total_Z_gained`, zmiany Haters/Morale, komunikat o `capped` jeśli >24h.

## Player Fantasy

Gracz wraca do gry i pierwsze co widzi to dowód, że jego imperium "żyło" bez niego — moment nagrody za samo wrócenie, analogiczny do otwierania powiadomień social media.

## Core Rules

**Decision**: ekran pojawia się tylko gdy `Δt ≥ 300s` (5 min) — krótsze przerwy wracają wprost do gry bez przerywania.

**Layout:**
1. Headline: wielka liczba `total_Z_gained` (K/M format z Action UI).
2. ΔHaters i Morale (z band label).
3. "You were offline for [X]" — czytelna jednostka.
4. Jeśli `capped=true`: dodatkowy komunikat.
5. Jeden przycisk "Continue!" (lub tap gdziekolwiek) do zamknięcia.

## Formulas

**format_duration**: największa jednostka {hours, minutes} gdzie Δt ≥ jej sekundy, round down. Max "24 hours" (nigdy "1 day").

## Visual/Audio Requirements

- **Headline count-up**: animuje od 0 do finalnej wartości, fixed duration niezależnie od magnitudy.
- **Morale band crash (no valence color-coding)**: band shift komunikowany przez magnitudę ruchu/skali, nigdy kolor.

---

## 15. GDD: Juice/Feedback System

# Juice/Feedback System

> **Implements Pillar**: Pillar 3
> Status: Designed (Vertical Slice tier), częściowo wdrożony (resolution_reaction w kartach)

## Overview

Juice/Feedback System to warstwa odpowiedzi na zdarzenia: (1) **sensoryczny juice** — efekty wizualne/audio skalowane magnitudą, (2) **resolution payoff** — krótka tekstowa reakcja po rozwiązaniu karty.

Bezpośrednia motywacja: pierwszy vertical slice (PIVOT) potwierdził działającą mechanikę, ale zerowy hook — "klikałem byle klikać". Ten system istnieje, by to naprawić.

## Player Fantasy

Gracz czuje **wielkość tego, co się właśnie wydarzyło** — niezależnie od tego, czy to dobrze czy źle dla niego wypadło. Decyzja, która zdetonowała wielki kontrakt sponsorski, ląduje z **dokładnie tą samą intensywnością** co decyzja, która wywołała viralowy sukces.

## Core Rules

1. Każde zdarzenie ma magnitude `0.0-1.0`.
2. **Action System** (częste): subtelniejszy kanał — count-up, light flash, brak shake.
3. **Decision Card System** (rzadkie, ważkie): silniejszy kanał — shake/scale-pulse skalowany magnitudą, audio stinger z rodziny tekstur (nie pitch), **plus resolution payoff**.
4. **Żaden kanał nigdy nie koduje walencji (dobre/złe) — tylko magnitudę.**

## Formulas

**Feedback magnitude**: `clamp(max(contribution per resource), 0.0, 1.0)` — linear dla bounded (Cringe/Morale), log-compressed dla unbounded (Reach/Sponsors/Haters).

**Payoff text duration**: `clamp(1.5 + (text_length/60)×1.0, 1.5, 2.5)` sekund.

## Visual/Audio Requirements (no-valence-coding — najważniejsza reguła)

- **Jeden neutralny token koloru** dla flash, identyczny niezależnie czy wynik dobry/zły.
- Audio stinger: **atonal** — żadnej melodii/harmonii. Magnituda steruje gęstością/decay/saturacją, nigdy pitch.
- **Validation method**: audition "big win" i "big disaster" mock event przy tej samej magnitudzie — muszą być nierozróżnialne emocjonalnie.

---

## 16. Art Bible Stub — kierunek wizualny

# Art Bible Stub — King of Cringe

**Tone descriptor**: Deadpan analytics dashboard for a clout economy — flat, observational, satirical; reads like a metrics readout, never a moral judgment.

**Locked direction:**
- **"Gamified Analytics" aesthetic** — think YouTube Studio / TikTok Analytics, nie spreadsheet (explicite unikanie failure mode z Beggar's Life).
- **Dark mode** (`#15151A` app background, `#2B2B36` card/button surfaces, `#FFFFFF` text).
- **Rounded, card-like surfaces** — corner_radius ~16-20px.
- **Resources as icon+color "pills"**, nie bare colored text.
- **Icon-first action buttons** — ikona to primary meaning-carrier.
- **Light "juice"**: zmiana wartości zasobu → scale-punch (~1.0→1.3→1.0, ~200ms).

## Palette Tokens

Data-driven, hue-distinct identity — **NIE valence-coded**.

| Token | Hex | Resource |
|---|---|---|
| `color_reach` | `#4A8A91` | Reach (muted teal) |
| `color_cringe` | `#9A6B92` | Cringe (muted mauve) |
| `color_haters` | `#6F62A8` | Haters (muted violet) |
| `color_morale` | `#A88F5C` | Morale (muted tan) |
| `color_sponsors` | `#5C8F68` | Sponsors (muted sage) |
| `color_activity` | `#E8E6F0` | Neutral flash/popup |

**Ważna lekcja designu**: oryginalne tokeny (jaśniejszy cyan-teal, magenta, fiolet, amber, zielony) były hue-distinct, ale wysoka saturacja+brightness czyniła kilka z nich walencjo-kodowanymi w praktyce — magenta Cringe odczytywana jako warning-red, amber Morale jako alarm. **Saturacja i jasność, nie sam hue, są faktycznymi nośnikami "alarmu"** — desaturacja/przygaszenie usunęło efekt bez utraty rozróżnialności.

## Typeface

Aktualnie: **VT323** (pixel font, SIL OFL 1.1) jako globalny font UI — pasuje do pixel-art ikon. Wcześniejszy smooth font (Open Sans) kolidował z pixel-art ikonami ("cheap 2005 Flash game" look).

---

## 17. Tech Debt Register — znane luki/kompromisy

> Pełna lista znanych kompromisów/luk w projekcie. Najważniejsze dla designera/kolegi z bocznej perspektywy:

- **Brak pola `category` na kartach** — modal karty pokazuje generyczną ikonę placeholder, bo schemat kart nie ma jeszcze taksonomii kategorii (sponsor/drama/hater/neutral). Treść tekstowa (text/label) jest już napisana dla wszystkich 12 kart.
- **Risky:Safe ratio dla 3 kart przekracza zadeklarowany Tuning Knob** (1.4-1.8x) — `staged_drama` (1.833x), `leaked_dm` (1.810x), `cancel_threat` (1.818x). Zaimplementowane jako-autorowane (czytane jako intencjonalne, wyższe stawki dla kart milestone-bearing) — do rewizji przy formalnym retuningu balansu.
- **Brak floor (0) dla Zasięgi/Sponsorzy** — Resource System nie definiuje dolnej granicy dla tych dwóch zasobów, mimo że niektóre karty mają koszty ujemne (np. `brand_deal_choice` -40 Reach). Gap między GDD-ami, nieformalnie rozwiązany.
- **`resolution_reaction` dla wszystkich 12 kart** — ROZWIĄZANE (2026-06-26): wszystkie karty mają teraz autorowaną reakcję, ton: suchy fakt/liczba, nigdy ocena.
- **Brak art bible w pełni** — istnieje tylko stub (sekcja 16) jako minimalny unblock; pełny art bible (9 sekcji) jest wciąż zobowiązaniem przed Production.
- **Licencje assetów do uznania w credits**: ikony (CC BY 4.0, Crusenho Agus Hennihuno) i font VT323 (SIL OFL 1.1) wymagają wzmianki w ekranie creditsów przed publicznym wydaniem — ekran creditsów jeszcze nie istnieje.
- **`SaveSystem.mark_dirty()` miało zero wywołań w kodzie** (RESOLVED 2026-06-29) — krytyczny bug znaleziony przez manualny playtest: zapis stanu nigdy nie był wywoływany podczas rozgrywki, więc nic nie przetrwało restartu. Naprawione.

---

## 18. Retrospektywa Sprint 6 — najnowsze wnioski z testów

## Retrospective: Sprint 6 — Action UI

### What Went Well
- **Pierwsza praca UI/scene w całym projekcie wysłana czysto**: 4 stories, 3 realne sceny Control-node, 18 automatycznych testów interakcji.
- **Direct user feedback na działającym buildzie złowił coś, czego review nie mogło**: po realnym odpaleniu sceny przez użytkownika, wyszły dwa realne gapy — nieczytelny Resource HUD (brak etykiet) i nieużywany resource art-direction (`art-bible-stub.md`'s color tokens, leżący nieużywany od przed tym sprintem).

### What Went Poorly
- **Realne naruszenie procesu**: gdy użytkownik zgłosił że HUD jest nieczytelny, agent przeszedł prosto do implementacji fixu (tekst, język, formatowanie) bez zapytania jak to powinno wyglądać — bezpośrednio z pominięciem Collaborative Design Principle. Użytkownik musiał to wprost wytknąć.
- **Fundamentalne, projektowe założenie o języku było błędne i odkryte późno**: język UI gry to angielski, ale duża część istniejącej treści (nazwy akcji w Action System, karty w Card Content Database, proza GDD) była zbudowana po polsku w wielu wcześniejszych sprintach, zanim to zostało wyjaśnione.
- **Nieobecność Card UI nie była widoczna aż użytkownik faktycznie zagrał w build**: backend `DecisionCardSystem` istniał od Sprintu 4, w pełni przetestowany, ale nic w żadnym UI nie subskrybowało go — więc karty nigdy faktycznie się nie pojawiały w rozgrywce.

### Action Items for Next Iteration
1. **Start the Card UI epic** — backend DecisionCardSystem był kompletny i nieprzetestowany-w-UI od Sprintu 4; to był największy gap między "testy przechodzą" a "gra jest faktycznie grywalna". *(Od tego czasu: zrobione — Card UI epic kompletny.)*
2. **Przed każdą future UI/visual story, explicite sprawdzić art-bible-stub.md FIRST i zapytać użytkownika o kierunek designu przed implementacją** — nie patchować defektów wizualnych jednostronnie.
3. Zaplanować deliberate pass Polish→English (nazwy akcji, treść kart, GDD prose) jako osobne, scoped zadanie.

### Summary
Genuinely dobry sprint na papierze — 100% completion, pierwsza praca scene/UI w projekcie wysłana czysto z silną dyscypliną testową — ale najwartościowszy wniosek przyszedł PO punkcie "done", gdy użytkownik faktycznie zagrał build i znalazł dwa realne gapy (nieczytelny HUD, niewidoczne karty), których żaden test suite nie mógł złowić. **Najważniejsza zmiana na przyszłość: traktuj "użytkownik faktycznie odpalił build" jako część Definition of Done, nie opcjonalny dodatek.**
