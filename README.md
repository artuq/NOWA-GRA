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

## Zawartość repozytorium

### Dokumentacja projektowa (`design/`)
- `design/gdd/` — 11 dokumentów Game Design dla wszystkich systemów MVP (zasoby, akcje, karty decyzji, UI, offline progress)
- `design/ux/` — UX interaction patterns i accessibility requirements
- `design/registry/` — dane projektowe i entity definitions

### Dokumentacja architektoniczna (`docs/`)
- `docs/architecture/` — Master Architecture, 6 Architecture Decision Records (ADRy), architektura systemów
- `docs/engine-reference/godot/` — notatki o Godot 4.6.3, breaking changes i dobre praktyki
- `docs/registry/` — architektoniczne rejestry i traceability

### Produkcja i logowanie (`production/`)
- `production/session-logs/` — dzienniki sesji, audyty agentów
- `production/session-state/` — stan aktualny i plany na kolejne sesje

### Testy (`tests/`)
- `tests/unit/` — testy jednostkowe (GDUnit4)
- `tests/integration/` — testy integracyjne
- `tests/smoke/` — ścieżki krytyczne (checklist smoke tests)

### Inne
- `CLAUDE.md` — architektura agentowa 49-osobowego zespołu Claude Code, zasady współpracy
- `prototypes/` — prototypy koncepcyjne i raporty z testów
- `.github/workflows/` — CI/CD (GitHub Actions)
- `.claude/agent-memory/` — pamięć agentów projektowych

## Struktura katalogów

```
.
├── CLAUDE.md
├── README.md
├── .github/
│   └── workflows/
├── .claude/
│   ├── agent-memory/
│   └── docs/
├── design/
│   ├── gdd/                    # 11 MVP game design docs
│   ├── ux/
│   └── registry/
├── docs/
│   ├── architecture/           # Master Architecture + 6 ADRy
│   ├── engine-reference/godot/
│   └── registry/
├── production/
│   ├── session-logs/
│   └── session-state/
├── prototypes/
└── tests/
    ├── unit/
    ├── integration/
    └── smoke/
```

## Technologie i narzędzia

- **silnik**: Godot 4.6.3
- **język**: GDScript
- **system budowania**: SCons + Godot Export Templates
- **testing**: GDUnit4
- **CI/CD**: GitHub Actions

## Obecny status

Projekt jest w **fazie projektowej zaawansowanej** (pre-production). Zawiera:
- ✅ 11 kompletnych GDDów dla MVP systemów
- ✅ Master Architecture z sign-offem Technical Director
- ✅ 6 zaakceptowanych ADRów (Architectural Decision Records)
- ✅ Ramy testów (GDUnit4)
- ✅ CI/CD workflow

Brak jeszcze pełnej implementacji gry w kodzie, ale architektura jest solidna i zatwierdzona.

## Planowane kolejne kroki

- Implementacja core systemów (Resource Manager, Action System, Offline Progress System)
- Implementacja persystencji (Save/Persistence System)
- Interfejsy użytkownika (Action UI, Card UI, Offline Report Screen)
- Onboarding i tutorial
- Vertical Slice: jedna kompletna, polakierowana ścieżka rozgrywki
- Playtest wczesny, sprawdzenie czy satyra jest odczytywana

## Jak czytać ten projekt

1. Start: `CLAUDE.md` — zrozumieć strukturę agentową i rules of engagement
2. Design: `design/gdd/game-concept.md` → `design/gdd/systems-index.md` → konkretne GDDy
3. Architektura: `docs/architecture/architecture.md` → poszczególne ADRy dla detali
4. Kod (kiedy będzie): `src/` → organizacja po modulach odpowiadających architekturze
