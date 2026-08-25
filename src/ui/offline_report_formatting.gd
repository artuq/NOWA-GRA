## OfflineReportFormatting is a stateless static utility holding the Offline
## Report Screen's one genuine display derivation: format_duration, which turns
## an elapsed-seconds count into a single-unit human label ("23 hours",
## "5 minutes"). Extracted into a pure static function (same precedent as
## ResourceFormulas / ActionUIFormatting / CardSwipeMath) so it's headlessly
## unit-testable against the GDD's exact acceptance criteria, per ADR-0009.
##
## Stateless-only invariant: never add instance vars or @export fields. The
## headline Zasięgi number is NOT formatted here — that reuses
## ActionUIFormatting.format_number (the shared K/M convention); this class owns
## only the duration string.
##
## Performance: O(1) per call.
##
## Duration nouns resolve through TranslationServer's plural table, including
## Polish singular/few/many forms. No gameplay value depends on the result.
##
## Usage example (English locale):
##   OfflineReportFormatting.format_duration(85620)  # -> "23 hours"
class_name OfflineReportFormatting
extends RefCounted

const SECONDS_PER_HOUR: int = 3600
const SECONDS_PER_MINUTE: int = 60

## Returns the offline duration as a single largest-whole-unit label, floored,
## with correct pluralisation, per offline-report-screen.md's format_duration:
##
##   pick the largest U in {hours, minutes} where elapsed_seconds >= U.seconds,
##   floor to a whole count, render "N unit(s)".
##
## No "days" tier — offline is capped at MAX_OFFLINE_CAP_SECONDS (86400 = 24h),
## so the maximum output is "24 hours". Single-unit only: no "1 hour 5 minutes"
## remainder is shown. The caller's contract guarantees
## [param elapsed_seconds] is within [300, 86400] (gated by the report
## threshold and the offline cap), so no sub-minute or over-cap handling is
## needed — the same trust-the-caller stance as the sibling utilities.
## Integer division floors naturally (3601/3600 = 1 -> "1 hour";
## 3599/60 = 59 -> "59 minutes").
##
## Usage example:
##   OfflineReportFormatting.format_duration(3600)  # -> "1 hour" (singular)
static func format_duration(elapsed_seconds: int) -> String:
	if elapsed_seconds >= SECONDS_PER_HOUR:
		var hours: int = elapsed_seconds / SECONDS_PER_HOUR
		return _duration_unit(
			&"OFFLINE_DURATION_HOUR_ONE", &"OFFLINE_DURATION_HOUR_MANY", hours
		)
	var minutes: int = elapsed_seconds / SECONDS_PER_MINUTE
	return _duration_unit(
		&"OFFLINE_DURATION_MINUTE_ONE", &"OFFLINE_DURATION_MINUTE_MANY", minutes
	)


static func _duration_unit(singular_key: StringName, plural_key: StringName, count: int) -> String:
	var template: String = TranslationServer.translate_plural(
		singular_key, plural_key, count
	)
	return template.replace("{count}", str(count))
