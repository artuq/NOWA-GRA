---
name: skill-improve
description: "Improve one editable Codex skill through a safe baseline, minimal patch, validation, and retest loop while preserving unrelated user changes."
---

# CCGS Codex Skill Improve

Use as `$skill-improve <skill-name>`. A direct request to improve a skill
authorizes the minimal in-scope edit described here; do not ask for redundant
per-file permission. Ask only when changing the skill's meaning, trigger, or
workflow policy would require a product decision.

## 1. Resolve the editable source

The only writable target is:

`plugins/ccgs-codex/skills/<name>/SKILL.md`

If the skill exists only in an installed/cache location, return `BLOCKED` with
that path. Never edit the cache. Verify the folder and frontmatter name agree.

## 2. Protect existing work

Before editing:

1. Read the full skill and its `agents/openai.yaml`.
2. Inspect `git diff -- plugins/ccgs-codex/skills/<name>/SKILL.md`.
3. Treat every pre-existing hunk as user-owned.
4. Record the exact baseline content or your own inverse patch, but do not use
   `git checkout`, `git restore`, reset, or any whole-file destructive revert.

## 3. Establish the baseline

Run the seven checks from `$skill-test static <name>` and record the tuple:

`(FAIL count, WARN count)`

If the testing catalog and category rubric exist, also run
`$skill-test category <name>`. If they are absent, report the concrete reason
and skip category scoring; never fabricate it. Behavioral spec coverage is
optional and may be `BLOCKED` independently.

## 4. Diagnose and propose the smallest fix

For every FAIL or WARN:

- cite the exact line or missing resource;
- explain the runtime or discovery impact;
- propose the smallest change that fixes it;
- avoid rewriting sections that already pass.

Show a concise diff preview. If the requested repair changes semantics or the
frontmatter description/trigger, present the decision and recommendation to the
user first. Pure format, broken-reference, and compatibility repairs may proceed.

## 5. Patch safely

Use `apply_patch` and touch only your planned hunks. Preserve pre-existing user
changes and unrelated files. Never commit.

If `name` or `description` changed, regenerate `agents/openai.yaml` with the
Codex skill metadata generator. Ensure `interface.default_prompt` contains the
exact `$<skill-name>` token.

## 6. Validate and retest

Run, in order:

1. the Codex quick skill validator;
2. YAML parse for `agents/openai.yaml`;
3. internal skill/role/resource reference checks;
4. `$skill-test static <name>`;
5. category checks when the rubric is available.

Compare results lexicographically: fewer FAIL first, then fewer WARN. A change
is never an improvement if it introduces a new critical schema, safety, or
unresolved-reference failure, even when the raw count falls.

## 7. Verdict and recovery

- `IMPROVED`: fewer FAIL, or equal FAIL with fewer WARN, and no new critical
  issue. Keep the patch and summarize it.
- `NO CHANGE`: same tuple. Explain why and offer one revised approach.
- `WORSE`: more FAIL/WARN or a new critical issue. Show the regression.

For `NO CHANGE` or `WORSE`, offer to reverse only the hunks introduced by this
workflow using the recorded inverse patch. Wait for approval before that
reversal, because later user edits may overlap. Never revert the whole file or
working tree.

End with the final tuple, validators run, unresolved limitations, and the next
exact `$skill-test` invocation.
