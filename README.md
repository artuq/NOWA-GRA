# NOWA GRA! — Król Cringe'u

## Opis projektu

„NOWA GRA!” to koncept mobilnej gry idle/incremental tycoon z narracyjnymi kartami decyzji. Gracz buduje imperium contentowe od małego pubu do internetu, a każda decyzja moralna wpływa na jego ścieżkę jako celebrytę lub patoinfluencera.

Projekt bazuje na idei „select-and-wait”, gdzie gracz wybiera akcje trwające w czasie, zamiast powtarzalnie klikać. Offline progress jest traktowany jako kluczowy element rozgrywki, a satyra ma być przekazywana przez mechanikę gry, nie przez wykłady.

## Kluczowe elementy

- gatunek: idle/incremental tycoon z elementami narracyjnymi
- platforma docelowa: mobile (Android, później iOS)
- styl rozgrywki: wybór akcji + karty decyzji moralnych
- główne systemy: zasoby, akcje, karty decyzji, mechanika offline, system flag historii
- ton: satyryczny, inspirowany internetową kulturą influencerów i patologią social media

## Zawartość repozytorium

- `CLAUDE.md` — architektura agentowa i zasady współpracy
- `design/gdd/` — dokumenty koncepcyjne i systemowe
- `docs/engine-reference/godot/` — notatki o Godot 4.6.3 i dobre praktyki
- `production/` — zapisy sesji, stan produkcji i dzienniki
- `prototypes/` — prototypy koncepcyjne z raportami

## Struktura

- `CLAUDE.md`
- `design/gdd/`
- `design/registry/`
- `docs/engine-reference/godot/`
- `production/session-logs/`
- `production/session-state/`
- `prototypes/`

## Technologia

Projekt zakłada użycie:

- silnika: Godot 4.6.3
- języka: GDScript
- systemu build: SCons + Godot Export Templates

## Status

Repozytorium jest obecnie w fazie projektowej i prototypowej. Zawiera głównie dokumentację, analizę koncepcji i prototypy, a nie pełną implementację gry.

## Następne kroki

- rozwinięcie MVP z podstawową pętlą akcji i offline progress
- zaprojektowanie systemu kart decyzji i flag historii
- przygotowanie pierwszego prototypu w Godot
- testowanie mechanik satyrycznej narracji bez moralizowania

## Uwaga

README dodane lokalnie i wypchnięte do zdalnego repozytorium GitHub. Nie zostały zmienione żadne inne pliki.
