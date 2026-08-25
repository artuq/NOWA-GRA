# Agent Coordination Rules for Codex

1. **Use the narrowest useful role.** Leadership agents coordinate broad or
   cross-domain decisions; specialists own bounded analysis or implementation.
2. **Keep decisions in the primary thread.** Subagents return evidence,
   tradeoffs, blockers, and recommendations. They do not ask the user directly.
3. **Resolve conflicts explicitly.** Escalate design conflicts to the
   `creative-director`, technical conflicts to the `technical-director`, and
   schedule/scope conflicts to the `producer`; the user owns the final choice.
4. **Propagate cross-domain changes.** Use `$propagate-design-change` and have
   the producer coordinate affected artifacts.
5. **Respect ownership and scope.** Agents must preserve unrelated changes and
   edit only the files required by their delegated task.

## Reasoning effort mapping

The port does not pin model slugs. Custom profiles set effort only, while the
model and permissions inherit from the active Codex session.

| Upstream tier | Codex effort | Typical use |
|---|---|---|
| Haiku | `low` | Lightweight status, formatting, narrow lookups |
| Sonnet, short role | `medium` | Focused QA/accessibility/audio checks |
| Sonnet | `high` | Implementation and single-system design/analysis |
| Opus | `xhigh` | High-stakes gates and cross-document synthesis |

## Multi-agent pattern

Use project profiles from `.codex/agents/*.toml` through Codex multi-agent
collaboration. Subagents inherit the parent task context that is explicitly
provided and return a distilled result.

Spawn work in parallel when the tasks are genuinely independent. Respect the
active concurrency limit: the primary agent occupies one slot, so larger
`team-*` workflows must run in batches. Do not create nested delegation trees
when the primary thread can coordinate the same work more clearly.

Use sequential delegation when one result defines another task's inputs. When
two agents touch the same file, either serialize their work or assign one as
read-only reviewer and one as owner.

## Parallel task protocol

1. Define a concrete, bounded task and expected output for every agent.
2. Start all independent tasks before waiting.
3. Collect every result before dependent synthesis.
4. Surface `BLOCKED`, negative gate verdicts, and dissent immediately.
5. Produce a partial report when some tasks finish and others block.
6. The primary agent resolves contradictions, cites evidence, and owns the
   final user-facing answer.

## Permissions

An audit/review delegation remains read-only. An implementation delegation may
edit only when the user's parent request authorized changes. Subagents never
commit, push, publish, or contact external systems unless the user explicitly
authorized that exact action.
