# Quick Design Spec: First-Launch Language Gate

**Type**: Addition
**System**: Start Screen / Settings System / Boot Flow
**GDD Reference**: `design/gdd/main-navigation-screen-flow.md`
**Date**: 2026-08-13

## Change Summary

A fresh installation must display an explicit `English / Polski` choice before
gameplay. System locale remains only the provisional presentation language.

## Rules

1. `language_choice_confirmed` defaults to false and is persisted in settings.
2. Boot shows Start Screen once when progress exists or language was never
   explicitly chosen.
3. Continue/Start Game is disabled until English or Polish is tapped.
4. Fresh careers hide Continue/New Game semantics and display Start Game.
5. Existing careers show the same language selector above Continue/New Game.
6. The selected language is synchronously saved before returning through boot.

## Acceptance Criteria

- [ ] Empty save routes to Start Screen.
- [ ] English and Polish are visible without relying on translation.
- [ ] Gameplay cannot start before a choice.
- [ ] Choosing a language changes copy immediately and survives reboot.
- [ ] Existing career Continue/New Game behavior remains intact.
