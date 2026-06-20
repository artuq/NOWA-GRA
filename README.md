# NOWA GRA! — Król Cringe'u

## Opis projektu

„NOWA GRA!” to projekt mobilnej gry idle/incremental tycoon z narracyjnymi kartami decyzji.
Gracz buduje imperium contentowe od małego pubu do internetowej marki, a decyzje moralne wpływają na jego rozwój jako influencera.

Projekt opiera się na mechanice „select-and-wait”, w której gracz wybiera działania trwające w czasie, zamiast powtarzalnie klikać. Offline progress jest traktowany jako kluczowy element rozgrywki. Satyra ma być wyrażana poprzez mechanikę i konsekwencje wyborów, a nie przez moralizujące komunikaty.

## Główne założenia

- gatunek: idle/incremental tycoon + narracyjne karty decyzji
- platforma: mobile (Android, później iOS)
- rozgrywka: wybieranie akcji, zarządzanie zasobami, karty decyzji moralnych
- kluczowe mechaniki: system zasobów, akcje trwające w czasie, oficjalny offline progress, system flag historii, ścieżki klas influencera
- ton: satyra na internetową kulturę influencerów, patoinfluencję i hazard w social media

## Zawartość repozytorium

- `CLAUDE.md` — architektura agentowa, zasady współpracy i dokumentacja procesowa
- `design/gdd/` — dokumenty game design dla systemów takich jak akcje, zasoby, karty decyzji i flagi historii
- `design/registry/` — dane projektowe, np. `entities.yaml`
- `docs/engine-reference/godot/` — notatki i najlepsze praktyki dla Godot 4.6.3
- `production/` — sesyjne logi, stan produkcji i dzienniki
- `prototypes/` — prototypy koncepcyjne i raporty z testów

## Struktura plików

- `CLAUDE.md`
- `design/gdd/`
- `design/registry/`
- `docs/engine-reference/godot/`
- `production/session-logs/`
- `production/session-state/`
- `prototypes/`

## Technologie i narzędzia

- silnik: Godot 4.6.3
- język: GDScript
- system budowania: SCons + Godot Export Templates

## Obecny status

Repozytorium jest w fazie projektowej i koncepcyjnej. Zawiera dokumentację, analizę systemów i prototypy, ale nie ma jeszcze pełnej implementacji gry.

## Planowane kolejne kroki

- dopracowanie MVP z podstawową pętlą akcji i offline progress
- opracowanie systemu kart decyzji oraz systemu flag historii
- przygotowanie prototypu w Godot oraz przetestowanie mechanik
- sprawdzenie, czy satyra jest odczytywana poprzez mechanikę, a nie opis

## Informacja

Ten plik README został zaktualizowany lokalnie i wypchnięty do zdalnego repozytorium GitHub. Nie zmieniono żadnych innych plików projektu.
