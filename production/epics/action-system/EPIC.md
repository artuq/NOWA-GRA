# Epic: Action System

> **Layer**: Core
> **GDD**: design/gdd/action-system.md
> **Architecture Module**: ActionSystem
> **Status**: Ready
> **Stories**: 2 stories created (2026-06-23)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | ActionSystem Core — Timer, Single-Concurrency & Progress | Logic | Ready | ADR-0004 |
| 002 | Action Reward Resolution & Morale Scaling | Integration | Ready | ADR-0004 + ADR-0001 |

## Overview

Implements the `ActionSystem` Autoload — the select-and-wait core loop's
mechanical backbone. Owns a single `Timer` node and a `current_action_id`
guard enforcing single-concurrency across the 3 actions (Record a Vlog / Start
Drama / Apologize Online, 4-9s durations). Exposes `start_action()`,
`get_progress()` (divide-by-zero guarded), and the `action_completed` signal
consumed by Decision Card System, Onboarding Gate, and Action UI.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Action System timer and single-concurrency enforcement | Single Timer + current_action_id guard; get_progress() divide-by-zero guard | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-act-001 | Single Timer with single-concurrency enforcement, 3 actions 4-9s | ADR-0004 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/action-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Stories created. Run `/story-readiness production/epics/action-system/story-001-action-core-timer-concurrency.md` then `/dev-story` to begin implementation. Work 001 before 002 (002 extends 001's `_on_action_timeout()`).
