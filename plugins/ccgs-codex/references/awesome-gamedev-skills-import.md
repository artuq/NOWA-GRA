# awesome-gamedev-agent-skills import

CCGS includes a vendored, Codex-adapted copy of the portable Agent Skills from
[`gamedev-skills/awesome-gamedev-agent-skills`](https://github.com/gamedev-skills/awesome-gamedev-agent-skills).

- Imported upstream revision: `9ca5296b219049c5b68494e1f3c274ead6d727b3`
- Import date: 2026-08-13
- Imported capabilities: 67 skills plus the adapted `$gamedev-skill-router`
- Upstream license: Apache License 2.0
- Reproducible importer: `scripts/import_awesome_gamedev_skills.py`
- Preserved legal files: `licenses/awesome-gamedev-agent-skills/`

## Local adaptations

1. Category-nested skill directories are flattened into the CCGS plugin's
   sibling `skills/<name>/` layout.
2. Codex `agents/openai.yaml` discovery metadata is added to each imported
   skill.
3. The router is renamed to `$gamedev-skill-router` to avoid a generic name and
   integrated underneath `$ccgs-studio`.
4. Existing-project engine pins override catalog baselines. King of Cringe stays
   on Godot 4.6.3 unless an explicit migration is approved.
5. CCGS remains responsible for production workflows, roles, gates, artifacts,
   and project memory; imported skills supply focused implementation knowledge.

## Refresh procedure

Clone or download a reviewed upstream revision, then run:

```bash
python3 plugins/ccgs-codex/scripts/import_awesome_gamedev_skills.py \
  /path/to/awesome-gamedev-agent-skills \
  plugins/ccgs-codex
```

After refreshing, update the revision above, validate the upstream bundle,
validate the Codex plugin, run `$skill-test static all`, and review API changes
against the project's pinned engine version before using new guidance.
