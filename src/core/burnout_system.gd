## BurnoutSystem owns the live-play sustained-Cringe trigger timer, its
## warning countdown, and forced Wypalenie card injection. It owns nothing
## PrestigeSystem already owns (era_count, resets, grants -- see ADR-0012)
## and nothing DecisionCardSystem already owns (card presentation/resolution
## mechanics) -- this Autoload's only job is to decide WHEN the Wypalenie
## card should appear, and (in a later story) route the player's A/B choice
## into PrestigeSystem's two entry points.
##
## Implements TR-pcs-007 / ADR-0013 "BurnoutSystem (new Autoload...)":
## registered as a new Core Autoload, after DecisionCardSystem in Project
## Settings -> Autoload (ADR-0013's Ordering Note -- a future story's
## _ready() will connect to DecisionCardSystem.card_resolved, which requires
## that node to already exist; registering in the correct position now avoids
## a reorder later). No ordering constraint exists against PrestigeSystem
## itself (calls into it happen at runtime post-boot, not from _ready()).
##
## Story 001 implemented the trigger-timer + warning-countdown portion of
## ADR-0013's pseudocode: _cringe_sustained_seconds increments every
## live-play frame while Cringe >= 100, resets (and cancels an active warning
## exactly once) the moment Cringe drops below 100, and burnout_warning_changed
## fires every frame the warning is active.
##
## Story 002 (this revision) adds the card-injection branch on top: once
## _cringe_sustained_seconds >= BURNOUT_THRESHOLD, _try_inject_burnout_card()
## force-presents the Wypalenie card via DecisionCardSystem.inject_priority_card(),
## guarded so it never clobbers a normal card mid-cycle and never silently
## soft-locks on a failed injection (see that method's own doc comment). The
## Wypalenie card's minimal real CardContentDatabase entry (id "final_burnout")
## was also added in this story (card_content_database.gd) -- see
## BURNOUT_CARD_ID's doc comment for the two option label strings Story 003
## must match.
##
## The following remain deferred to later stories and are NOT implemented
## here (see story-002-card-injection-guard-rails.md's Out of Scope):
##   - Story 003: _on_card_resolved() / _ready()'s DecisionCardSystem.
##     card_resolved.connect() wiring, and routing Choice A/B into
##     PrestigeSystem.on_burnout_accepted()/on_burnout_deferred()
##   - Story 004: restore_state()/serialize_state() (ADR-0003 boot protocol)
##     for _card_pending -- _cringe_sustained_seconds is intentionally never
##     persisted (Final Burnout quick-spec's Pillar 4: "no surprise burnout
##     on app open")
##
## Tuning knobs (BURNOUT_THRESHOLD, BURNOUT_WARNING_THRESHOLD): ADR-0013's
## pseudocode comments mark these as "balance.json" values, but no
## assets/data/balance.json exists anywhere in this project yet -- every
## other tuning knob an ADR describes the same way (ClassPathSystem's
## _INVESTMENT_RATE_TABLE, ADR-0010 §8; PrestigeFormulas' BASE_INCREMENT /
## META_BONUS_MAX) is, in the shipped code, a plain GDScript const. This file
## follows that same already-shipped pattern, not the ADRs' aspirational
## data-file text (docs/tech-debt-register.md tracks the project-wide
## extraction-to-real-data-file item; not yet scheduled).
##
## Usage example:
##   BurnoutSystem.burnout_warning_changed.connect(_on_warning_changed)
extends Node

## Fires every live-play frame while the sustained-Cringe warning is active
## (active=true), with seconds_remaining = BURNOUT_THRESHOLD -
## _cringe_sustained_seconds (uncapped -- may go negative once the trigger
## threshold itself is crossed; Story 002 owns acting on that crossing, this
## story only reports it). Fires exactly once with (false, 0.0) the frame the
## warning cancels (Cringe drops below 100), never repeatedly afterward.
signal burnout_warning_changed(active: bool, seconds_remaining: float)

## Seconds Cringe has been continuously >= 100 during live play. Never
## advances during OfflineProgressSystem.simulate_offline() (Pillar 4) --
## only this Autoload's own _process() writes to it, and
## OfflineProgressSystem never calls into BurnoutSystem. Resets to 0.0 the
## moment Cringe drops below 100. Intentionally NOT persisted (see this
## file's header comment).
var _cringe_sustained_seconds: float = 0.0

## True while the Wypalenie card is injected and awaiting the player's A/B
## choice. Set true by _try_inject_burnout_card() on a successful
## DecisionCardSystem.inject_priority_card() call (Story 002); cleared by
## Story 003's _on_card_resolved() once the player resolves the card.
## Persisted via serialize_state()/restore_state() -- Story 004.
var _card_pending: bool = false

## Sustained-Cringe seconds required before the Wypalenie card force-injects
## (Story 002). ADR-0013/quick-spec default; see this file's header comment
## for why this is a plain const rather than a balance.json load.
const BURNOUT_THRESHOLD: float = 300.0

## Sustained-Cringe seconds required before burnout_warning_changed(true, ...)
## starts firing. ADR-0013/quick-spec default; see this file's header comment
## for why this is a plain const rather than a balance.json load.
const BURNOUT_WARNING_THRESHOLD: float = 180.0

## Wypalenie ("Final Burnout") card's CardContentDatabase id. Force-injected
## via DecisionCardSystem.inject_priority_card() by [method _try_inject_burnout_card]
## below -- never presented through the normal weighted-random pool
## (CardContentDatabase's entry for this id uses trigger_condition "never",
## specifically to exclude it from _build_eligible_pool()'s normal
## selection -- see that entry's own comment in card_content_database.gd).
##
## Story 003 (Choice A/B routing into PrestigeSystem, out of this story's
## scope) matches DecisionCardSystem.card_resolved's option_chosen against
## this card's authored option "label" fields -- NOT semantic identifiers --
## since resolve_choice() derives option_chosen from option["label"]
## (decision_card_system.gd:311), not a separate id. The two exact label
## strings authored on this card (card_content_database.gd) are:
##   "Accept the Burnout" -> Choice A (PrestigeSystem.on_burnout_accepted())
##   "Defer the Burnout"  -> Choice B (PrestigeSystem.on_burnout_deferred())
## A future edit to either label string in CardContentDatabase MUST be
## mirrored in Story 003's _on_card_resolved() comparison, or that routing
## silently no-ops both branches.
const BURNOUT_CARD_ID: StringName = &"final_burnout"


## O(1) per live-play frame (control-manifest.md Core layer guardrail): one
## ResourceManager.get_resource() call, one comparison, occasional signal
## emit, no allocation. Implements this story's 4 ACs exactly per ADR-0013's
## pseudocode:
##   AC-1: Cringe >= 100 -> _cringe_sustained_seconds += delta, every frame
##   AC-2: Cringe < 100 -> _cringe_sustained_seconds resets to 0.0, same frame
##   AC-3: _cringe_sustained_seconds >= BURNOUT_WARNING_THRESHOLD ->
##         burnout_warning_changed(true, seconds_remaining) every frame while
##         active
##   AC-4: warning active + Cringe drops below 100 ->
##         burnout_warning_changed(false, 0.0) exactly once (guarded by the
##         "> 0.0" check below -- once _cringe_sustained_seconds is already
##         0.0, the next below-100 frame does not re-emit)
func _process(delta: float) -> void:
	var cringe: float = ResourceManager.get_resource(&"Cringe")
	if cringe >= 100.0:
		_cringe_sustained_seconds += delta
		if _cringe_sustained_seconds >= BURNOUT_WARNING_THRESHOLD:
			burnout_warning_changed.emit(true, BURNOUT_THRESHOLD - _cringe_sustained_seconds)
		if _cringe_sustained_seconds >= BURNOUT_THRESHOLD and not _card_pending:
			_try_inject_burnout_card()
	else:
		if _cringe_sustained_seconds > 0.0:
			burnout_warning_changed.emit(false, 0.0)
		_cringe_sustained_seconds = 0.0


## Story 002 (TR-pcs-007, ADR-0013's guard-rail correction): forces the
## Wypalenie card via the already-shipped DecisionCardSystem.inject_priority_card()
## (ADR-0012 §4). Two guard rails, per ADR-0013's own validation pass:
##   1. Never clobbers a normal card mid-cycle -- guarded on
##      DecisionCardSystem.state == COOLDOWN before attempting injection; if a
##      normal card is CHECKING/PRESENTING/RESOLVING, this simply returns and
##      retries next frame (harmless -- _cringe_sustained_seconds is
##      deliberately NOT reset until injection actually succeeds, so the
##      trigger condition stays latched, never silently lost).
##   2. inject_priority_card() returns bool, not void -- a discarded false
##      return (misconfigured BURNOUT_CARD_ID, or a priority card already
##      pending from elsewhere) would otherwise soft-lock BurnoutSystem
##      forever (never sets _card_pending, so `not _card_pending` keeps
##      retrying, but the call keeps failing the same way every frame).
##      push_error() makes this loud, not silent.
## Implements ADR-0013's _try_inject_burnout_card() pseudocode exactly, no
## deviation.
func _try_inject_burnout_card() -> void:
	if DecisionCardSystem.state != DecisionCardSystem.State.COOLDOWN:
		return  # mid-cycle on a normal card -- retry next frame, no reset
	if DecisionCardSystem.inject_priority_card(BURNOUT_CARD_ID):
		_card_pending = true
		_cringe_sustained_seconds = 0.0
	else:
		push_error("BurnoutSystem: inject_priority_card(%s) returned false -- " %
			BURNOUT_CARD_ID + "verify this id exists in CardContentDatabase")
