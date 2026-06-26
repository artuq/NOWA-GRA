## Unit tests for OfflineReportFormatting (Story 001, Offline Report Screen epic).
## Covers format_duration against the GDD's exact duration ACs. Pure static
## utility — no scene tree or Autoload dependency, same pattern as
## ActionUIFormatting / CardSwipeMath.
extends GdUnitTestSuite

## AC: 300s -> "5 minutes" (threshold floor).
func test_five_minutes() -> void:
	assert_str(OfflineReportFormatting.format_duration(300)).is_equal("5 minutes")

## AC: 3599s (1s under an hour) -> "59 minutes", still in the minutes tier.
func test_fifty_nine_minutes_just_under_an_hour() -> void:
	assert_str(OfflineReportFormatting.format_duration(3599)).is_equal("59 minutes")

## AC: 3600s -> "1 hour" (singular, exact hour boundary, unit switch).
func test_one_hour_singular() -> void:
	assert_str(OfflineReportFormatting.format_duration(3600)).is_equal("1 hour")

## AC: 3601s -> "1 hour" (single-unit, no remainder shown).
func test_one_hour_no_remainder() -> void:
	assert_str(OfflineReportFormatting.format_duration(3601)).is_equal("1 hour")

## AC: 85620s -> "23 hours".
func test_twenty_three_hours() -> void:
	assert_str(OfflineReportFormatting.format_duration(85620)).is_equal("23 hours")

## AC: 86400s (max cap) -> "24 hours", never "1 day" / "1440 minutes".
func test_twenty_four_hours_at_cap() -> void:
	assert_str(OfflineReportFormatting.format_duration(86400)).is_equal("24 hours")

## AC: pluralisation — 60s -> "1 minute" (singular).
func test_one_minute_singular() -> void:
	assert_str(OfflineReportFormatting.format_duration(60)).is_equal("1 minute")

## AC: pluralisation — 120s -> "2 minutes" (plural).
func test_two_minutes_plural() -> void:
	assert_str(OfflineReportFormatting.format_duration(120)).is_equal("2 minutes")

## AC: pluralisation — 7200s -> "2 hours" (plural hours).
func test_two_hours_plural() -> void:
	assert_str(OfflineReportFormatting.format_duration(7200)).is_equal("2 hours")
