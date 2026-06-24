## Unit tests for ActionUIFormatting (Story 001, Action UI epic). Covers
## number-formatting boundaries, progress bar fill_ratio, and the GDD's
## defined edge cases. No scene tree or Autoload dependency -- ActionUIFormatting
## is a pure static utility class, same testing pattern as ResourceFormulas.
extends GdUnitTestSuite

## AC: 847 -> "847" (no K/M abbreviation under 1000)
func test_format_number_under_thousand_returns_plain_integer() -> void:
	assert_str(ActionUIFormatting.format_number(847.0)).is_equal("847")

## AC: 999 -> "999" (just under the K threshold)
func test_format_number_just_under_k_threshold_returns_plain_integer() -> void:
	assert_str(ActionUIFormatting.format_number(999.0)).is_equal("999")

## AC: 1,000 -> "1.0K" (inclusive lower bound -- the critical boundary test)
func test_format_number_at_k_threshold_returns_one_point_zero_k() -> void:
	assert_str(ActionUIFormatting.format_number(1000.0)).is_equal("1.0K")

## AC: 28,412 -> "28.4K"
func test_format_number_mid_k_range_truncates_to_one_decimal() -> void:
	assert_str(ActionUIFormatting.format_number(28412.0)).is_equal("28.4K")

## AC: 999,999 -> "999.9K" (truncation, not rounding -- would be "1000.0K"
## under normal rounding, which is exactly why this implementation truncates)
func test_format_number_just_under_m_threshold_truncates_not_rounds() -> void:
	assert_str(ActionUIFormatting.format_number(999999.0)).is_equal("999.9K")

## AC: 1,000,000 -> "1.0M" (hard boundary)
func test_format_number_at_m_threshold_returns_one_point_zero_m() -> void:
	assert_str(ActionUIFormatting.format_number(1000000.0)).is_equal("1.0M")

## Deviation from the GDD's own stated example (1,250,000 -> "1.3M"): per the
## user-decided resolution documented in ActionUIFormatting.format_number()'s
## doc comment, truncation is used everywhere, so this locks the REAL
## measured behavior (1.2M), not the GDD's internally-inconsistent example.
func test_format_number_mid_m_range_truncates_per_resolved_deviation() -> void:
	assert_str(ActionUIFormatting.format_number(1250000.0)).is_equal("1.2M")

## AC: negative value displays as-is, no UI-layer clamping
func test_format_number_negative_value_displays_with_sign_preserved() -> void:
	assert_str(ActionUIFormatting.format_number(-50.0)).is_equal("-50")

## Coverage gap closed (flagged by code review): negative K-scale value --
## proves sign_str/abs() logic combines correctly with the K-truncation branch,
## not just the plain-integer branch above.
func test_format_number_negative_k_scale_preserves_sign_and_truncates() -> void:
	assert_str(ActionUIFormatting.format_number(-28412.0)).is_equal("-28.4K")

## Coverage gap closed (flagged by code review): negative M-scale value.
func test_format_number_negative_m_scale_preserves_sign_and_truncates() -> void:
	assert_str(ActionUIFormatting.format_number(-1250000.0)).is_equal("-1.2M")

## Coverage gap closed (flagged by code review): zero is an unstated but real
## boundary -- falls into the plain-integer branch, must not error or show a
## sign.
func test_format_number_zero_returns_plain_zero_no_sign() -> void:
	assert_str(ActionUIFormatting.format_number(0.0)).is_equal("0")

## AC: elapsed_time=0, duration>0 -> fill_ratio=0
func test_fill_ratio_at_zero_elapsed_returns_zero() -> void:
	assert_float(ActionUIFormatting.fill_ratio(0.0, 9.0)).is_equal_approx(0.0, 0.0001)

## AC: 0<elapsed_time<duration -> fill_ratio=clamp(E/D,0,1)
func test_fill_ratio_partway_through_returns_correct_ratio() -> void:
	assert_float(ActionUIFormatting.fill_ratio(4.5, 9.0)).is_equal_approx(0.5, 0.0001)

## AC: elapsed_time==duration -> fill_ratio=1 (boundary inclusive)
func test_fill_ratio_at_duration_returns_one() -> void:
	assert_float(ActionUIFormatting.fill_ratio(9.0, 9.0)).is_equal_approx(1.0, 0.0001)

## AC: elapsed_time>duration -> fill_ratio=1 (clamped, never exceeds)
func test_fill_ratio_past_duration_clamps_to_one() -> void:
	assert_float(ActionUIFormatting.fill_ratio(12.0, 9.0)).is_equal_approx(1.0, 0.0001)
