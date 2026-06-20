# Unit Tests

`resource_system/resource_formulas_test.gd` is an example test confirming the
test naming/structure convention and GdUnit4 syntax — it targets
`res://src/core/resource_formulas.gd`, which is specified by ADR-0006 but not
yet implemented (no `src/` code exists yet; this is Technical Setup, not
Production). This test will fail/error until that file is written — that's
expected. Treat it as a template for the first real unit test once
implementation begins, not as a currently-passing test.
