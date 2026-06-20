# Example test confirming the GdUnit4 framework is wired up correctly.
# Tests ResourceFormulas.haters_growth_rate() per ADR-0006 / resource-system.md.
# H_rate(C) = H_base + (C / 100)^H_exp x H_max_add
# H_base=0.02, H_exp=2.0, H_max_add=1.0 (per design/registry/entities.yaml constants)
extends GdUnitTestSuite

const ResourceFormulas = preload("res://src/core/resource_formulas.gd")

func test_haters_growth_rate_at_zero_cringe_returns_h_base() -> void:
    var rate := ResourceFormulas.haters_growth_rate(0.0)
    assert_float(rate).is_equal_approx(0.02, 0.0001)

func test_haters_growth_rate_at_max_cringe_returns_h_base_plus_h_max_add() -> void:
    var rate := ResourceFormulas.haters_growth_rate(100.0)
    assert_float(rate).is_equal_approx(1.02, 0.0001)  # 0.02 + (1.0)^2.0 * 1.0

func test_haters_growth_rate_at_half_cringe_is_between_bounds() -> void:
    var rate := ResourceFormulas.haters_growth_rate(50.0)
    assert_float(rate).is_greater(0.02)
    assert_float(rate).is_less(1.02)
