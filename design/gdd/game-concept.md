# Game Concept: Król Cringe'u

*Created: 2026-06-19*
*Status: Draft*

---

## Elevator Pitch

> To jest idle/incremental tycoon, w którym budujesz imperium contentowe od pustego pubu do internetowej celebryckiej marki — a satyryczne karty decyzji moralnych w stylu "Reigns" kierują Cię na ścieżki patoinfluencingu albo czystszej sławy, podczas gdy gra uczciwie liczy Twój postęp nawet offline.

---

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

---

## Core Fantasy

"Jestem twórcą internetowym budującym własne imperium contentowe — i widzę, krok po kroku, jak system (Algorytm, sponsorzy, hejterzy) kształtuje kim się stałem." Gracz dostaje satysfakcję optymalizatora (czysta matematyka progresji jak w Melvor), ale każda decyzja moralna ma realną wagę w tym, jaką ścieżką "celebryty" się stanie.

---

## Unique Hook

To jest jak Melvor Idle, AND ALSO każda karta decyzji moralnej (jak w Reigns) nieodwracalnie kieruje Cię na satyryczną ścieżkę klasy — Guru-Celebrytę albo Pato-Streamera Hazardowego — bez wykładu, tylko przez to co gra nagradza i karze.

---

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

---

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

---

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

---

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

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Melvor Idle | Model select-and-wait (wybierz akcję, ona biegnie automatycznie), czysta matematyka progresji | Dodajemy satyryczne karty decyzji jako bramki do ścieżek klas | Potwierdza, że głębia systemowa + prosty art działa na mobile |
| Beggar's Life | Drzewko klas zależne od wyborów, abstrakcyjne zasoby (wina/wdzięczność) | Naprawiamy przeładowane UI i nadmiar aktywnego klikania; mocna matematyka offline | Pokazuje potencjał tematu "od zera do imperium", ale ostrzega przed błędami UX |
| Idle Research: Endless Tycoon | Tycoon-style skalowanie liczb, automatyczne generowanie w czasie | Wprowadzamy narracyjną warstwę satyryczną zamiast czysto abstrakcyjnego tematu | Potwierdza apetyt rynku na tycoon-idle z głębokimi systemami |

**Non-game inspirations**: Kultura patoinfluencerów i internetowych "callout" kryzysów, mechaniki hazardowe w grach free-to-play (loot boxy, "kasyno sponsorów"), formaty kart decyzji w stylu Reigns.

### Reference Game Findings (2026-06-20)

Zastosowano jednolitą listę pytań playtestowych (`production/playtests/playtest-question-guide.md`) do nagrań z 4 gier referencyjnych, mimo że pytania były pisane pod mechanikę naszej gry (swipe + karty). Wynik: tylko Reigns dostał werdykt PROCEED — pozostałe trzy dostały PIVOT, bo mechanicznie/tematycznie nie pokrywają się z naszą grą. To jest informacja, nie porażka metody — pokazuje precyzyjnie, **który element każdej gry faktycznie przenosi się na nasz projekt, a który nie**.

| Reference | Verdict na nasze pytania | Co realnie potwierdza/zmienia w naszym projekcie |
|---|---|---|
| **Reigns** | PROCEED | Najbliższy mechanicznie i tonalnie. Potwierdza fundament: swipe + narracyjny payoff działa, onboarding przez sam gest (brak tutoriala), brak potrzeby precyzyjnego dotyku. **Nowy wniosek**: Reigns ma stałe napięcie 4 wskaźników frakcji przez całą rozgrywkę z realną stawką (śmierć władcy) — u nas Cringe/Morale/Hatersi robią coś podobnego, ale **nie mamy zdefiniowanej realnej stawki "przegranej"/zakończenia ery**, analogicznej do śmierci władcy. Otwarte pytanie do rozważenia przy projektowaniu Prestige/Checkpoint System (Alpha tier). |
| **Melvor Idle** | PIVOT (mechanicznie/tematycznie niezgodny) | Number-go-up + zablokowane sloty **działają jako hook niezależnie od tematu** — potwierdza decyzję o lockowanych Action Grid slotach. **Ostrzeżenie**: gęstość UI tej gry byłaby blokerem na dotyku — potwierdza naszą decyzję o oszczędnym UI (3 akcje, nie dziesiątki zakładek). |
| **Idle Research: Endless Tycoon** | PIVOT (mechanicznie/tematycznie niezgodny) | Potwierdza number-go-up jako solidny, niezależny hook. **Ostrzeżenie**: przy bardzo dużych liczbach (e50, e100) recenzent zgłosił, że liczby zmieniają się w "szum w tle", nieczytelny postęp — flaguje potrzebę monitorowania, czy nasz K/M format (`action_ui_number_format`) wystarcza na długą rozgrywkę, czy potrzeba dalszych jednostek (M, potem co?). |
| **Beggar's Life** | PIVOT (tematycznie niezgodny — to symulator bezdomności, nie satyra na influencerów) | Ton "mozolnego, przytłaczającego" postępu (nie triumfalnego) jest bliżej naszej satyry niż heroiczna fantazja Melvora — wzmacnia decyzję, że King of Cringe nie powinien czuć się jak czyste heroiczne wbijanie poziomów. Mechanizm "chcę zobaczyć jak źle/absurdalnie to się potoczy" zadziałał tam dobrze — to ten sam mechanizm, na którym stoi nasza eskalacja Cringe; potwierdza potencjał, warunkowany dobrym pisaniem treści kart. |

**Metodologiczny wniosek na przyszłość**: przy kolejnych badaniach referencyjnych, jeśli gry referencyjne różnią się mechanicznie (nie wszystkie mają karty/swipe), warto przygotować pytania uniwersalne na poziomie *hooka* (np. "czy chciałeś zrobić jeszcze jedno", nie "czy karta Cię zaskoczyła") — część pytań z tej rundy nie miała zastosowania do 3 z 4 gier i dała odpowiedzi typu "to pytanie nie ma zastosowania", co jest poprawne, ale mniej informacyjne niż mogłoby być.

---

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

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot — lekki, dobry na mobile, deklaracja użytkownika |
| **Key Technical Challenges** | Matematyka offline progress (delta czasu), system flagów historii kart decyzji, event-driven architektura (sygnały, nie `_process`) dla baterii |
| **Art Style** | 2D, warstwowe sprite'y, UI-first |
| **Art Pipeline Complexity** | Low — minimalistyczny, bez animacji szkieletowych |
| **Audio Needs** | Moderate — feedback przy zakończeniu cyklu akcji i kartach decyzji |
| **Networking** | None |
| **Content Volume** | MVP: ~10-15 kart decyzji, 2 ścieżki klas. Full vision: 40+ kart, 4+ ścieżki klas, 3 zakończenia-checkpointy |
| **Procedural Systems** | Brak proceduralnej generacji w MVP |

---

## Risks and Open Questions

### Design Risks
- Satyra może nie być odczytana jako satyra — gracz po prostu optymalizuje liczby bez refleksji nad tematem.
- Model select-and-wait może czuć się "zbyt pasywny" bez wystarczająco częstych kart decyzji do aktywnego zaangażowania.

### Technical Risks
- Matematyka offline progress i system flagów historii kart to dwa serca silnika — muszą być solidne od dnia 1.
- Zarządzanie stanem wielu równoległych akcji trwających w czasie (różne timery) wymaga przemyślanej architektury sygnałów w Godot.

### Market Risks
- Segment idle/incremental jest zatłoczony — temat satyryczny musi być widoczny już w pierwszych ekranach store'u, by się wyróżnić.

### Scope Risks
- "Tygodnie" na MVP z drzewkiem klas + kartami + offline math jest ambitne — łatwo rozjedzie się do miesięcy.

### Open Questions
- Jak dokładnie system flagów historii determinuje dostępność ścieżek klas? — wymaga prototypu/dokumentu systemowego.
- Jaki jest model monetyzacji, który nie zaprzecza satyrze na hazard? — do rozstrzygnięcia przed `/design-system` ekonomii.
- **Czy potrzebujemy "realnej stawki" analogicznej do śmierci władcy w Reigns?** (z Reference Game Findings, 2026-06-20) — gra ma świadomą decyzję anty-porażkową (konsekwencje odroczone, nigdy blokujące na stałe), ale Reigns pokazuje, że ciągłe napięcie 4 wskaźników z realną stawką jest mocnym hookiem. Nie chcemy kopiować permadeath, ale **Prestige/Checkpoint System (Alpha tier)** może być naturalnym miejscem na "koniec ery"/transformację bez game-over. *Owner: `/design-system "Prestige/Checkpoint System"` po zakończeniu Vertical Slice tier, zgodnie z `systems-index.md`'s kolejnością. Target: Alpha.*

---

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

## Next Steps

- [ ] Get concept approval from creative-director
- [ ] Fill in CLAUDE.md technology stack based on engine choice (`/setup-engine`)
- [ ] Create game pillars document (`/design-review` to validate)
- [ ] **Prototype core idea** (`/prototype select-and-wait-loop`) — przed pisaniem GDD zweryfikować, że pętla bez tapowania jest satysfakcjonująca
- [ ] If prototype PROCEEDS: Decompose concept into systems (`/map-systems`)
- [ ] Design each system (`/design-system [system-name]`) — użyć wniosków z prototypu w sekcjach Tuning Knobs i Formulas
- [ ] Build vertical slice in Pre-Production (`/vertical-slice`) — zwalidować pełną pętlę gry przed Production
- [ ] Validate core loop with playtest (`/playtest-report`)
- [ ] Plan first milestone (`/sprint-plan new`)
