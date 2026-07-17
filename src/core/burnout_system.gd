## BurnoutSystem owns the live-play sustained-Cringe trigger timer and its
## warning countdown. It owns nothing PrestigeSystem already owns (era_count,
## resets, grants -- see ADR-0012) and nothing DecisionCardSystem already
## owns (card presentation/resolution) -- this Autoload's only job is to
## decide WHEN the Wypalenie card should appear, and (in a later story) route
## the player's A/B choice into PrestigeSystem's two entry points.
##
## Implements TR-pcs-007 / ADR-0013 "BurnoutSystem (new Autoload...)":
## registered as a new Core Autoload, after DecisionCardSystem in Project
## Settings -> Autoload (ADR-0013's Ordering Note -- a future story's
## _ready() will connect to DecisionCardSystem.card_resolved, which requires
## that node to already exist; registering in the correct position now avoids
## a reorder later). No ordering constraint exists against PrestigeSystem
## itself (calls into it happen at runtime post-boot, not from _ready()).
##
## Story 001 (this revision) implements ONLY the trigger-timer + warning-
## countdown portion of ADR-0013's pseudocode: _cringe_sustained_seconds
## increments every live-play frame while Cringe >= 100, resets (and cancels
## an active warning exactly once) the moment Cringe drops below 100, and
## burnout_warning_changed fires every frame the warning is active. The
## following are explicitly deferred to later stories and are NOT
## implemented here (see story-001-trigger-timer-warning.md's Out of Scope):
##   - Story 002: the card-injection branch (_cringe_sustained_seconds >=
##     BURNOUT_THRESHOLD -> DecisionCardSystem.inject_priority_card()) --
##     marked with a comment at its would-be call site below, matching
##     ADR-0013's own pseudocode comment
##   - Story 003: _on_card_resolved() / _ready()'s DecisionCardSystem.
##     card_resolved.connect() wiring, and routing Choice A/B into
##     PrestigeSystem.on_burnout_accepted()/on_burnout_deferred()
##   - Story 004: restore_state()/serialize_state() (ADR-0003 boot protocol)
##     for _card_pending -- _cringe_sustained_seconds is intentionally never
##     persisted (Final Burnout quick-spec's Pillar 4: "no surprise burnout
##     on app open")
##
## _card_pending is declared here (unpopulated -- always false until Story
## 002 sets it) since it's part of this class's state shape per ADR-0013,
## even though this story never writes to it.
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
## choice. Declared here per ADR-0013's state shape; always false until
## Story 002 sets it on a successful DecisionCardSystem.inject_priority_card()
## call. Persisted via serialize_state()/restore_state() -- Story 004.
var _card_pending: bool = false

## Sustained-Cringe seconds required before the Wypalenie card force-injects
## (Story 002). ADR-0013/quick-spec default; see this file's header comment
## for why this is a plain const rather than a balance.json load.
const BURNOUT_THRESHOLD: float = 300.0

## Sustained-Cringe seconds required before burnout_warning_changed(true, ...)
## starts firing. ADR-0013/quick-spec default; see this file's header comment
## for why this is a plain const rather than a balance.json load.
const BURNOUT_WARNING_THRESHOLD: float = 180.0


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
		# Card injection trigger (>= BURNOUT_THRESHOLD) is Story 002 -- this
		# story stops at detecting the threshold-crossing state, not acting
		# on it.
	else:
		if _cringe_sustained_seconds > 0.0:
			burnout_warning_changed.emit(false, 0.0)
		_cringe_sustained_seconds = 0.0
