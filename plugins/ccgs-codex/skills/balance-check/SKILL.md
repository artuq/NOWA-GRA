---
name: balance-check
description: Analyzes game balance data files, formulas, and configuration to identify outliers, broken progressions, degenerate strategies, and economy imbalances. Use after modifying any balance-related data or design. Use when user says 'balance report', 'check game balance', 'run a balance check'.
---

## Codex compatibility

Invoke this workflow as `$balance-check` followed by any arguments in the user's prompt.
Map the legacy Read/Glob/Grep/Write/Edit/Bash names to the available Codex tools; use `apply_patch` for repository edits.
Use the available user-input mechanism only when a decision materially changes the result. If running as a subagent, return 2–4 concise options and a recommendation to the parent instead of questioning the user directly.
Delegate independent work through Codex subagents when useful, respecting the active concurrency limit and batching larger teams.
A direct user request to build or change something authorizes in-scope edits; do not repeat legacy per-file approval prompts. Audits and reviews remain read-only unless the user also asks for changes. Never commit or push unless asked.
Legacy tool profile (guidance only): `Read, Glob, Grep, Write, user-input`.
Recommended role: `economy-designer` from `.codex/agents/economy-designer.toml`. Keep the primary thread responsible for user-facing choices.

---

## Phase 1: Identify Balance Domain

Determine the balance domain from `invocation argument 1 from the user text after $balance-check`:

- **Combat** → weapon/ability DPS, time-to-kill, damage type interactions
- **Economy** → resource faucets/sinks, acquisition rates, item pricing
- **Progression** → XP/power curves, dead zones, power spikes
- **Loot** → rarity distribution, pity timers, inventory pressure
- **File path given** → load that file directly and infer domain from content

If no argument, infer the domain from the request and repository evidence. For a general balance request, default to a project-wide economy + progression audit. Ask only when multiple plausible domains would materially change scope.

---

## Phase 2: Read Data Files

Discover the project's actual balance sources instead of assuming fixed folders. Start with an explicit path argument when provided, then inspect existing sources in this order:

1. `design/balance/` and `assets/data/`, when they exist;
2. `design/registry/entities.yaml` and the relevant `design/gdd/` documents;
3. formula, manager, content-database, and progression code under `src/`;
4. unit/integration tests that lock expected values or boundary behavior.

Missing conventional folders are not a blocker. Use focused search for formulas, rates, costs, rewards, caps, cooldowns, weights, and multipliers. Note every file read for the report's Data Sources section.

---

## Phase 3: Read Design Document

Read the GDD for the system from `design/gdd/` to understand intended design targets,
tuning knobs, and expected value ranges. This is the baseline for "correct" behaviour.

---

## Phase 4: Perform Analysis

Run domain-specific checks:

**Combat balance:**
- Calculate DPS for all weapons/abilities at each power tier
- Check time-to-kill at each tier
- Identify any options that dominate all others (strictly better)
- Check if defensive options can create unkillable states
- Verify damage type/resistance interactions are balanced

**Economy balance:**
- Map all resource faucets and sinks with flow rates
- Project resource accumulation over time
- Check for infinite resource loops
- Verify gold sinks scale with gold generation
- Check if any items are never worth purchasing

**Progression balance:**
- Plot the XP curve and power curve
- Check for dead zones (no meaningful progression for too long)
- Check for power spikes (sudden jumps in capability)
- Verify content gates align with expected player power
- Check if skip/grind strategies break intended pacing

**Loot balance:**
- Calculate expected time to acquire each rarity tier
- Check pity timer math
- Verify no loot is strictly useless at any stage
- Check inventory pressure vs acquisition rate

---

## Phase 5: Output the Analysis

```
## Balance Check: [System Name]

### Data Sources Analyzed
- [List of files read]

### Health Summary: [HEALTHY / CONCERNS / CRITICAL ISSUES]

### Outliers Detected
| Item/Value | Expected Range | Actual | Issue |
|-----------|---------------|--------|-------|

### Degenerate Strategies Found
- [Strategy description and why it is problematic]

### Progression Analysis
[Graph description or table showing progression curve health]

### Recommendations
| Priority | Issue | Suggested Fix | Impact |
|----------|-------|--------------|--------|

### Values That Need Attention
[Specific values with suggested adjustments and rationale]
```

---

## Phase 6: Fix & Verify Cycle

After presenting the report, use `Codex user-input mechanism`:
- Prompt: "Balance check complete. What would you like to do next?"
- Options:
  - `[A] Fix highest-priority issue now — walk me through it`
  - `[B] Save report to design/balance/balance-check-[system]-[date].md`
  - `[C] Stop here — I'll review the findings manually`

If [A]:
- Ask which issue to address first (refer to the Recommendations table by priority row)
- Change the authoritative source actually discovered during the audit: prefer data/config when present, otherwise the governing GDD/registry or formula code
- After each fix, offer to re-run the relevant balance checks to verify no new outliers were introduced
- If the fix changes a tuning knob defined in a GDD or referenced by an ADR, remind the user:
  > "This value is defined in a design document. Run `$propagate-design-change [path]` on the affected GDD to find downstream impacts before committing."

If [B]:
- Write the report to `design/balance/balance-check-[system]-[date].md` (create the directory if needed). Use the current date for [date] in YYYY-MM-DD format.
- Confirm the file was written, then end with: "Re-run `$balance-check` after fixes to verify."

If [C]:
- Summarize open issues and end with: "Re-run `$balance-check` after fixes to verify."
