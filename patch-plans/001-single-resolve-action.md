Patch note for Claude: unify claim resolution to a single `resolve` action

The spec has been corrected to use a single host-triggered `resolve` action in `checking`,  rather than the previous `resolve_winner` and `resolve_loser` actions..

What changed:
- The final claim resolution step is a single action: `resolve`.
- The host still triggers it after `check`.
- The admin process then finalizes the claim as either `winner` or `cheater` depending on the host decision.
- Do not split this into `resolve_winner` and `resolve_cheater`.

Required implementation update:
- In the host app, keep the action set as: `next_game`, `start_drawing`, `pause`, `resume`, `check`, `resolve`.
- Use the exact action names as button labels.
- When the app is in `checking`, show a single `resolve` action and let the host say when to progress the outcome in the admin flow; do not create a second “winner/cheater” action split.
- Keep the write contract the same: each action writes its name via Firebase `push()` to `/actions/<pushid>`.

Do not invent extra action names beyond the above contract.

The source-of-truth behavior is:
- `check` moves `game_state` from `claiming` -> `checking`
- `resolve` moves `game_stage` from `checking` -> `winner` or `cheater`
- the host is still the actor that triggers both actions
