# Directory Structure

```text
/
├── AGENTS.md                    # Project instructions and CCGS routing
├── .codex/
│   ├── agents/                  # 49 project custom-agent TOML profiles
│   ├── agent-memory/            # Project-scoped role memory
│   └── docs/                    # Project standards used by Codex
├── .agents/plugins/             # Repo marketplace entry
├── plugins/ccgs-codex/          # Portable CCGS plugin source
│   ├── skills/                  # 73 workflows plus ccgs-studio router
│   ├── hooks/                   # Codex lifecycle and validation hooks
│   ├── references/              # Gates, workflow catalog, testing rubric
│   └── assets/                  # Agent templates and document templates
├── src/                         # Game source (core, gameplay, UI, tools)
├── assets/                      # Game art, audio, resources, and data
├── design/                      # GDDs, UX, registries, art, and balance
├── docs/                        # Architecture and engine references
├── tests/                       # Unit, integration, performance, playtest
├── tools/                       # Build and pipeline tooling
├── prototypes/                  # Throwaway prototypes and slices
└── production/                  # Sprints, QA, gates, state, and releases
```

The legacy `.claude/` tree is retained as migration source and fallback memory;
new Codex work should use the paths above.
