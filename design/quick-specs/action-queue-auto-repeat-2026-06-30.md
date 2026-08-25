# Quick Design Spec: Action Queue with Auto-Repeat

**Type**: Addition
**System**: Action System + Action UI
**GDD Reference**: `design/gdd/action-system.md`, `design/gdd/action-ui.md`
**Date**: 2026-06-30

## Change Summary

Dodaje kolejkę akcji do istniejącej maszyny stanów ActionSystem.
Gracz może dodać kilka akcji z góry; po zakończeniu bieżącej akcja
startuje automatycznie z kolejki. Kolejka pauzuje gdy pojawi się
karta decyzyjna lub Morale wejdzie w stan Critical.

## Motivation

Pillar 4 (offline first-class): gracz może zostawić grę działającą
z zakolejkowanymi akcjami i wrócić do wyników, zamiast stukać co
kilka sekund. Bez kolejki idle/incremental loop wymaga aktywnej
obecności — to sprzeczne z gatunkiem.

## Design Delta

Obecny GDD (`action-system.md`, Detailed Rules) mówi:

> **If the player tries to choose an action while `running`**:
> request rejected — UI must disable action buttons while in the
> `running` state.

Ten spec zmienia to na:

Gdy stan to `running`, wybór akcji dodaje ją do kolejki (nie
startuje natychmiast). Akcje z kolejki startują automatycznie gdy
stan przejdzie z `resolved` → `idle`. Gracz może anulować
kolejkę w dowolnym momencie.

## New Rules / Values

**Kolejka:**
- Kolejka to `Array[StringName]` action_id, przechowywana w ActionSystem
- Gracz może kolejkować dowolną akcję (base + odblokowane gated)
- Po przejściu resolved → idle: jeśli kolejka niepusta →
  auto-start `queue.pop_front()` → stan `running`
- Anulowanie: przycisk "Clear Queue" czyści `Array`; bieżąca
  akcja dobija do końca (bez przerwania)

**Auto-pauza (suspend, nie clear):**
- Decision Card pojawia się → kolejka zawieszona (nie opróżniona);
  bieżąca akcja dobiega końca, następna nie startuje
- Morale ≤ CRITICAL_THRESHOLD → kolejka zawieszona
- Obie pauzy znikają automatycznie gdy warunek odpada

**Cap:**
- `QUEUE_CAP: int = 10` — tuning knob
- Powyżej capu: przycisk akcji wyszarzony z tooltipem "Queue full"

**UI — wizualizacja:**
- Pod Action Grid: poziomy pasek ikon zakolejkowanych akcji
  (max 10 ikon, ta sama ikona co w przycisku akcji)
- Ikona "×" na końcu paska → Clear Queue
- Stan suspended: pasek zyska półprzezroczystość (alpha 0.5),
  bez ikony X (nie można anulować podczas karty)

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| ActionSystem (`action_system.gd`) | Dodać `_queue: Array[StringName]`, logikę auto-start, suspend | Kod |
| ActionGrid (`action_grid.gd`) | Render paska kolejki, disable przy cap, clear button | Kod |
| DecisionCardSystem | Emituje już signal gdy karta się pojawia — ActionSystem subskrybuje | Wire signal |
| ResourceManager | ActionSystem sprawdza `Morale` vs CRITICAL_THRESHOLD przy każdym resolved | Read-only |
| SaveSystem | Kolejka jest efemeryczna — **nie zapisywać** (zgubi się i tak przy zamknięciu) | Brak |

## Acceptance Criteria

- [x] Zakolejkowana akcja startuje automatycznie po zakończeniu
  bieżącej, bez interakcji gracza
- [x] Queue cap = 10; powyżej przyciski akcji są wyłączone
- [x] Pojawienie się karty decyzyjnej zawiesza kolejkę (bieżąca
  dobiega, następna nie startuje)
- [x] Morale ≤ Critical zawiesza kolejkę tak samo
- [x] Clear Queue czyści tablicę; bieżąca akcja dobija do końca
- [x] UI pasek ikon odzwierciedla stan kolejki w czasie rzeczywistym
- [x] Kolejka nie jest persystowana — reset przy każdym starcie gry
- [x] Brak regresji: pojedyncze akcje (bez kolejkowania) działają
  identycznie jak przed zmianą

## GDD Update Required?

Tak — `design/gdd/action-system.md`, sekcja Detailed Rules:
zmienić regułę "request rejected while running" na opis kolejkowania.
Dodać kolejkę jako tuning knob do sekcji Tuning Knobs.
