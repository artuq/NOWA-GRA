## ActionUIFormatting is a stateless static utility class holding Action UI's
## pure display-formatting math: large-number K/M abbreviation and progress
## bar fill ratio. Follows the same precedent as ResourceFormulas
## (res://src/core/resource_formulas.gd) -- extracted into static functions
## so they're unit-testable without a scene tree, per ADR-0007's
## Implementation Guidelines.
##
## Performance: O(1) pure arithmetic/string formatting, negligible even
## called every frame from RunningActionOverlay's _process() loop (Story 004)
## -- no profiling required at this scale.
##
## Usage example:
##   var label: String = ActionUIFormatting.format_number(28412.0)  # -> "28.4K"
##   var ratio: float = ActionUIFormatting.fill_ratio(4.5, 9.0)  # -> 0.5
class_name ActionUIFormatting
extends RefCounted

## Formats [param value] per action-ui.md's K/M abbreviation rule:
## under 1000 -> plain integer string; 1000 to under 1,000,000 -> one
## decimal place + "K"; 1,000,000 and above -> one decimal place + "M".
##
## **Truncates, never rounds**, to one decimal place. This is a documented
## deviation from one of the GDD's own worked examples (see story-001's
## Implementation Notes): the GDD's K-scale example (999999 -> "999.9K")
## and M-scale example (1250000 -> "1.3M") cannot both be satisfied by a
## single consistent rounding rule -- truncation satisfies the K example
## exactly (999.999 truncated = 999.9) but means 1250000 formats as "1.2M",
## not the GDD's stated "1.3M". User-decided resolution (2026-06-24):
## truncation everywhere; the GDD's M-scale example is the error, not this
## implementation. Truncation also has the structural advantage of never
## letting a K-scale value round up into displaying "1000.0K" instead of
## crossing into the M scale.
##
## Negative values are formatted as-is (sign preserved, magnitude scaled
## normally) -- no UI-layer clamping, per the GDD's explicit edge case.
##
## Usage example:
##   ActionUIFormatting.format_number(847.0)      # -> "847"
##   ActionUIFormatting.format_number(28412.0)     # -> "28.4K"
##   ActionUIFormatting.format_number(1250000.0)   # -> "1.2M" (see deviation note above)
static func format_number(value: float) -> String:
	var sign_str: String = "-" if value < 0.0 else ""
	var magnitude: float = abs(value)

	if magnitude < 1000.0:
		return "%s%d" % [sign_str, int(magnitude)]

	if magnitude < 1000000.0:
		var truncated_k: float = floor(magnitude / 100.0) / 10.0
		return "%s%.1fK" % [sign_str, truncated_k]

	var truncated_m: float = floor(magnitude / 100000.0) / 10.0
	return "%s%.1fM" % [sign_str, truncated_m]


## Returns the progress bar fill ratio for [param elapsed_time] out of
## [param duration], per action-ui.md's Progress Bar Fill rule:
##
##   fill_ratio = clamp(elapsed_time / duration, 0.0, 1.0)
##
## [param duration] of 0 is explicitly out of scope -- Action System's own
## invariant says a zero-duration action "should not occur" (per story-001's
## Out of Scope); this function does not guard against it, since doing so
## would mean asserting behavior for a contract violation rather than this
## GDD's actual behavior.
##
## Usage example:
##   ActionUIFormatting.fill_ratio(0.0, 9.0)   # -> 0.0
##   ActionUIFormatting.fill_ratio(4.5, 9.0)   # -> 0.5
##   ActionUIFormatting.fill_ratio(12.0, 9.0)  # -> 1.0 (clamped)
static func fill_ratio(elapsed_time: float, duration: float) -> float:
	return clamp(elapsed_time / duration, 0.0, 1.0)
