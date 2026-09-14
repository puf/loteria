# Implementation Plan

## Decisions Captured

* Player app: web required; Flutter web allowed.
* Host app: web required; Flutter web allowed.
* Stage/admin app: likely web; Flutter web allowed.
* Player auth: Firebase anonymous auth.
* Host auth: prefer Firebase Google auth; Firebase email/password acceptable fallback.
* Firebase emulators: optional; use whichever path is easier during implementation.
* Backend orchestration: no Cloud Functions.
* Countdown timer: in memory only in the admin/stage process.
* Draw history: not stored in the database.
* Card order / draw sequence: derived from `game_id` as PRNG seed.
* `blocked_uids`: cleared every round.
* Host may get a command to clear `blocked_uids` manually.
* `claim_log` and `winner_log`: continuous streams across sessions.
* Player UI asset (provided): [assets/loteria_assets/cards-sprite.png](assets/loteria_assets/cards-sprite.png).
* Stage audio asset (for later stage/admin work): [assets/loteria_assets/cards.mp3](assets/loteria_assets/cards.mp3).
* Initial implementation/testing approach: start with the player app and drive it by direct database writes or test fixtures.
* The Firebase project has already been created and is named `laloteria`.

## Tentative Build Order

* Player app read path first.
* Player app write path next (`lobby/<uid>`, `game/claiming_uid`).
* Host app after player flows are proven.
* Stage/admin process after host and player read/write contracts are proven.

## Open Questions

* [RESOLVED, 2026-09-14] Host/stage recovery behavior after reload or restart: every engine (`DrawLoopEngine`, `StageStateController`, etc.) resumes purely from live DB state (`game_state` + `draw_count`), so a reload mid-round just re-syncs -- no separate recovery logic needed.
* [RESOLVED, 2026-09-14] Whether the stage app needs a dedicated recovery/control surface beyond the host app: no -- the stage app is a pure read-only projection of DB state; the host app is the only control surface, by design.
* Parking-lot feature ideas to revisit later: host clear-blocklist command (in progress, 2026-09-14), explicit player feedback when a `loteria` write is rejected ([DECIDED against for v1] -- see `player/lib/services/game_repository.dart`'s `writeClaim` doc comment: a rejection is expected/legitimate and deliberately not surfaced as an error, to keep the UI stable), and other non-v1 polish items.

## Deferred / Follow-up Items

* [RESOLVED, 2026-09-14] Define the exact draw/pause fields in `game` before coding begins -- `game/draw_count`, `game/game_id`, `game/claiming_uid`, `game/winning_pattern` are all implemented and in active use.
* [RESOLVED, 2026-09-14] Finalize player reconnect behavior by game state once the Player App scaffold is underway -- `PresenceService` writes `lobby/<uid>` on connect with an `onDisconnect` removal handler, and all player screens are a live projection of DB state, so reconnect is handled by the same architecture as the stage app's recovery.
* [RESOLVED, 2026-09-14] Revisit host/stage recovery and control-surface questions later in the host/stage work -- see Open Questions above.
* Keep a parking-lot list for non-v1 polish items, such as clearing `blocked_uids` via host command (in progress, 2026-09-14) and explicit player feedback when a `loteria` write is rejected (decided against for v1, see above).

## Player App Scaffold (v1)

### Scope for this section

* Implement only the player app flow and UI behavior.
* Defer host/stage implementation details except where they affect player read/write contracts.

### Player asset inputs

* Card sprite sheet: [assets/loteria_assets/cards-sprite.png](assets/loteria_assets/cards-sprite.png). This sprite sheet contains two rows totalling 55 cards.

* The card announcement audio file [assets/loteria_assets/cards.mp3](assets/loteria_assets/cards.mp3) is intentionally excluded from player app inputs and reserved for stage/admin implementation.

* Additional resources may be used from
  * `loteria_assets/svg-sprite.svg` (vertical) sprite sheet which contains miscelanious images.
  * Any other files from `loteria_assets`.

### Firebase read paths (player)

* `game_state`
* `game`
* `players/<uid>`
* `blocked_uids/<uid>`

* *all card and other imagery and metadata are loaded from bundled assets.

### Firebase write paths (player)

* `lobby/<uid>`: write `true` when connecting, register `onDisconnect` handler to delete on disconnect.
* `game/claiming_uid`: write current user UID when the user claims loteria in the player UI (this write may be rejected by the server/database).

### Player screen states (port-over)

* Unauthenticated: sign-in screen.
* Authenticated + `game_state=lobby`: show "waiting for next game".
* `game_state=dealing` and `players/<uid>.tabla_id` absent: show "waiting for tabla".
* `game_state=dealing` and `players/<uid>.tabla_id` present: show tabla and "waiting to start".
* `game_state=drawing`: allow player to put beans on tabla and click Loteria button.
* `game/claiming_uid == uid`: flash whole screen between white and normal to allow claim confirmation visual.
* `game_state=claiming` and `game/claiming_uid != uid`: show tabla
* `game_state=checking`: show tabla and "checking claim" while waiting for host to resolve claim.
* `game_state=winner` or `game_state=celebrate`: show tabla and "somebody won"

### Loteria button behavior (v1)

* Enabled only when:
	* `game_state == drawing`
  * `game/claiming_uid` is empty
	* `blocked_uids/<uid>` does not exist
* Disabled otherwise.
* If write to `game/claiming_uid` is rejected by rules, keep UI stable and do not show extra error in v1.

### Local player-only state (not in database)

* Bean placements on tabla.
* Derived local completion state for enabling the Loteria button.
* Any transient UI animation state.

Bean placement is only persisted in local storage. This storage is cleared when the game starts.

### Reconnect behavior

* On reconnect, the player should re-subscribe to the current Firebase state and resume from the authoritative state already in the database.
* The reconnect flow should be state-driven, not a separate reconnect-only UI flow.
* For `lobby`, follow the normal flow.
* For `dealing`, wait for the current `tabla_id` to be written before resuming the dealing flow.
* For `drawing`, `claiming`, `checking`, `winner`, and `celebrate`, re-read the relevant Firebase state, including `tabla_id` when needed, then restore any persisted local bean placements and resume the same screen flow.
* No special reconnect-specific UI state is required beyond restoring the correct current state and local board state.

### Player implementation slices (coding order)

* Slice P1: auth + lobby presence write.
* Slice P2: attach Firebase listeners + state-to-screen router.
* Slice P3: dealing and tabla display states.
* Slice P4: drawing view + local bean placement.
* Slice P5: loteria button + write loteria claim to DB + server-driven claimant flash + claiming/checking/winner transitions.
* Slice P6: reconnect handling + polish pass.


### Player test plan scaffold (v1)

* Phase 1: manual Firebase state injection to validate each screen state.
* Phase 2: reusable fixtures (console scripts or emulator data seeds) once the player flow is stable.
* Phase 3: widget/unit tests for screen routing and button enablement rules once the read/write contracts are settled.

Emulator-based tests are optional for v1. The priority is to validate the player flow manually first and add emulator or automated test coverage only when it materially speeds up iteration or catches regressions.




## Stage view + Admin app scaffold

This application owns the admin process for the game and drives the main display shown on the conference projector. It is a single Flutter web app built in the `server` subdirectory as a **sibling** to the `player` directory.

### Decisions

* Privileged auth model: local Flutter web app on the laptop; any Firebase auth is acceptable for the browser session; admin access is granted through a custom `isAdmin` claim assigned by a Firebase Admin SDK script.
* Runtime: stage/admin app is a Flutter web app on the conference laptop, projected to the stage.
* Action source: remote control app is the only action source in v1; the stage/admin app is authoritative for game state but does not submit actions directly.
* Database access: the stage/admin app has unrestricted read/write access to the Firebase database in v1, matching the spec’s admin rules.
* Recovery scope: v1 includes basic restart recovery, but not a full fault-tolerant recovery system.
* Stage UI: `claiming` uses the normal drawing view with a clear claim signal; no dedicated claim screen is required in v1.
* Remote control actions: use the exact action names from the spec as the UI labels.
* Draw/pause metadata: no persisted `paused` field in `game` in v1; pause remains an admin-only control signal.
* Minimum recovery behavior: after reload/restart, resume the previous phase and restore already-drawn card history; losing the exact countdown is acceptable if the app resumes safely.
* Stage-only control surface: none is needed in v1; all game control happens in the remote control app.
* Action request IDs: no explicit request-ID strategy is needed in v1; single-host, low-volume actions are not expected to cause replay problems.

### App purpose

* Build the projected stage display and the authoritative game admin for the current round.
* The stage/admin app is responsible for the live state machine, draw loop, claim validation, and winner/cheater resolution.
* The remote control app is not authoritative; it sends actions and reads status.

### Runtime and auth

* Runtime: Flutter web app running locally on the conference laptop.
* Device target: laptop + projector, with the stage display mirrored or projected live.
* Auth model: Firebase auth is acceptable for the browser session; admin access is granted by the custom `isAdmin` claim assigned by the backend bootstrap script.
* Privileged access: the app is allowed to act as the authoritative admin only after that custom claim is present.

### Responsibilities

#### Stage display

* Show the current drawn card.
* Show draw history or recent card list.
* Show active player count or lobby status.
* Show a claimant signal while `game.claiming_uid` is non-empty.
* Show winner, cheater, and celebrate states.
* Show QR or join instructions when relevant.

#### Admin authority

* Own the state machine.
* Own timers and draw cadence.
* Validate or reject claim actions.
* Resolve winner/cheater flows.
* Rebuild current phase after reload/restart.

### Data contract

The stage/admin app has unrestricted database access in v1. Specific paths are called out only where a slice needs them.

#### Local-only state

* current draw cursor or card index
* in-memory timer state
* current phase UI state
* recent draw history for display
* claimant cue state

### Stage UI screen inventory

This section is a concrete screen list of whatever the stage display already knows from the spec. It is not a mock layout; it is the required UI content per state.

#### Screen: `lobby`

Known UI elements:
* explanation of what the game is
* join instructions, via URL and/or QR code
* current player count
* a start-game control for the host
* a strong welcoming visual treatment for the audience-facing display

#### Screen: `dealing`

Known UI elements:
* text like "Dealing tabla %d of %d"
* total number of players in the game
* progress indicator for how many tablas have been assigned
* quick animation of cards being dealt or handed out

#### Screen: `drawing`

Known UI elements:
* the current card as the main reveal
* draw animation when the card is displayed
* optional progress bar/time remaining between draws
* recent card history or a visible draw strip
* audio announcement of the card name from [assets/loteria_assets/cards.mp3](assets/loteria_assets/cards.mp3)
* a large visible claim cue when `game.claiming_uid` becomes non-empty

#### Screen: `claiming`

Known UI elements:
* the most recent `claiming_uid`
* the associated `tabla_id` or visual table preview
* claim result state: accepted or rejected in the host/admin flow
* a visible stage cue that a claim is pending
* host-side confirmation or check action trigger

#### Screen: `checking`

Known UI elements:
* the current claimant being held up for verification
* the current table or player claim under review
* a waiting state while the host resolves the claim
* large instruction to the player to hold up their phone and show it

#### Screen: `cheater`

Known UI elements:
* false-bingo / cheater animation
* countdown for the rejection timeout
* clear indication that the claim was rejected

#### Screen: `winner`

Known UI elements:
* winner banner or winner announcement
* winner player identity
* winning `tabla_id` or result context if needed
* transition into celebration mode

#### Screen: `celebrate`

Known UI elements:
* fireworks or celebratory visual effect
* winner result on the stage
* Loteria card animations or celebration graphics
* a high-energy end-of-round moment before reset

### Stage display polish requirements

The stage display is the primary public-facing screen, so it should feel lively and legible from a distance.

* The current card is the center of gravity of the whole screen.
* Each draw should feel like an event: clear animation, strong contrast, and big typography.
* The card name announcement should be audio-synced with the visual reveal.
* When `claiming_uid` is active, the stage should clearly highlight the claimant and temporarily pause the draw cadence.
* A recent-card strip or ticker helps the audience understand the draw sequence.
* Winner and cheater states should be visually obvious and high contrast.
* The overall visual style should stay readable in a bright conference room from far away.

### Admin state machine

This mirrors the spec rather than inventing new design. The admin app owns the authoritative transitions below; the stage display is a live projection of Firebase state, not a separate source of truth.

* `lobby`
  * trigger: `next_game`
  * action: choose a new `game_id`, snapshot current players, generate and assign `tabla_id` values, then enter `dealing`
  * next state: `dealing`
* `dealing`
  * trigger: `start_drawing`
  * action: verify every player has a `tabla_id`; if all are assigned, start the draw cadence and set `game_state = drawing`
  * next state: `drawing`
  * reject: `start_drawing` if any player is still missing a `tabla_id`
* `drawing`
  * trigger: timed `draw_tick`
  * action: generate the next unique card from the `game_id` seed, update current card, emit card animation/audio, increment the draw count, and continue drawing until pause, end-of-deck, or a player claims LOTERIA.
  * next state: `drawing`
* `drawing`
  * trigger: player writes a valid `game/claiming_uid`
  * action: verify `game_state == drawing`, `claiming_uid` empty, UID not in `blocked_uids`; if valid, pause draw cadence and set `game_state = claiming`
  * next state: `claiming`
* `claiming`
  * trigger: `check`
  * action: look up `tabla_id`, validate the claim; if valid or this is the first invalid claim in the game, transition to `checking`
  * next state: `checking`
* `claiming`
  * trigger: automatic silent reject
  * action: append rejected outcome to `claim_log`, add `claiming_uid` to `blocked_uids`, clear `claiming_uid`, return to `drawing`
  * next state: `drawing`
* `checking`
  * trigger: `resolve` (single action, per patch-plans/001 -- not split into `resolve_winner`/`resolve_cheater`)
  * action: look up the already-computed claim outcome (`claim_log`'s most recent entry for this claim, decided back when the claim came in) and finalize accordingly -- accepted: acknowledge the claimant as winner and move to `winner`; rejected: treat the claim as a false claim, show cheater flow, and enter `cheater`
  * next state: `winner` or `cheater`
* `cheater`
  * trigger: countdown timeout
  * action: add the UID to `blocked_uids`, clear `claiming_uid`, and resume `drawing`
  * next state: `drawing`
* `winner`
  * trigger: winner finalization
  * action: append to `winner_log`, set `game_state = celebrate`
  * next state: `celebrate`
* `celebrate`
  * trigger: `next_game`
  * action: clear `players` and any needed `blocked_uids` state and return to lobby setup
  * next state: `lobby`

The admin app does not invent extra states beyond those already present in the spec; it wires the defined transitions, timers, and database writes to the existing flow.

### Remote control action contract

Host actions available to the remote-control app:

* `next_game`
  * source: remote control app
  * effect: reset state and clear round data as defined in spec
  * validation: only possible when the current `game_state` is `lobby`
* `start_drawing`
  * source: remote control app
  * effect: begin draw loop
  * validation: only possible when the round is ready and `game_state` is `dealing` or `drawing`
* `pause`
  * source: remote control app
  * effect: pause draw cadence
  * validation: only possible while the draw loop is active
* `resume`
  * source: remote control app
  * effect: resume draw cadence
  * validation: only possible while the draw loop is paused
* `check`
  * source: remote control app
  * effect: move claim to checking state
  * validation: only possible when `game_state` is `claiming`
* `resolve`
  * source: remote control app
  * effect: finalize the claim as winner or cheater, based on the outcome already logged to `claim_log` when the claim came in -- not a separate host choice
  * validation: only possible when `game_state` is `checking`

### Timer and draw logic

* Draw interval: 5s
* Draw source: the card sequence must be derived from the current `game_id` as the PRNG seed. The `game_id` is already required by the player app and is the canonical source for the randomized card order.
* Draw tracking: maintain a running count of how many cards have already been drawn in the current round. This count is the authoritative cursor for determining the next card and for reconstructing the draw history after reload/restart.
* Draw animation: when a card is drawn, animate it onto the stage display as the active card. The card should be visually revealed in the draw transition before the next phase is resumed.
* Audio cue: when a card is drawn, play the corresponding segment of [assets/loteria_assets/cards.mp3](assets/loteria_assets/cards.mp3). The file is a linear recording of all card names, so the stage/admin app should map the current draw position to the appropriate audio slice and trigger it at the draw moment.
* Pause behavior: the screen shows the same content as before, but all disabled.
* Deck handling: if the deck ever becomes empty, show a large "No more cards" label over the existing displays.
* Draw history: The current card is shown large in the center of the screen. To the right of that, the previous 3 cards are shown, each subsequently smaller and more dimmed.

### Recovery policy

* On reload/restart, the stage/admin app should rebuild its view from the current Firebase state.
* Reconstruct current phase from `game_state`.
* Reconstruct drawn-card history from persisted state or logs.
* If exact timer state is lost, resume in the nearest safe state.
* If the phase was `drawing`, recovering the draw count is required; exact countdown timing can be approximate.

### Implementation slices

* A0: Firebase Admin bootstrap script to grant `isAdmin` custom claim to the host UID
* A1: app shell + privileged auth
* A2: Firebase listeners and state routing
* A3: lobby and round start flow
* A4: dealing flow
* A5: draw loop and pause/resume
* A6: claim flow and checking state
* A7: winner / cheater / celebrate
* A8: restart recovery
* A9: polish and final QA

### Test plan scaffold

* Phase 1: manual Firebase state injection for each admin state.
* Phase 2: action fixtures for `next_game`, `start_drawing`, `pause`, `resume`, and claim resolution.
* Phase 3: recovery checks after reload/restart.
* Phase 4: edge-case validation for empty deck, invalid claim, and duplicate actions.

## Host view / Remote control app scaffold

This app is the control surface for the live game, which the host runs on their mobile phone. It reads the current Firebase state and emits the actions that the admin app acts on. It (generally) is not authoritative and does not own the game state machine. It is not normally shown to players, so doesn't have to be pretty/appealing.

### Scope

* Host-side controls for starting a round, drawing, pausing/resuming, and resolving claims.
* Read-only status view for the current phase, claimant, player count, and current card.
* Compact UI designed for a mobile or laptop host device.
* No stage display responsibilities.

### Decisions

* Auth model: same as the stage/admin app; sign in anonymously, display the current UID and write `false` to `admins/<uid>` in the database, a person then grants `isAdmin` via the bootstrap script. This app does not need a separate rich auth flow.
* UI shape: a single scrollable host console is sufficient for v1. It may be built in Flutter, but it does not have to be.
* Host controls: no dedicated UI to clear `blocked_uids`; the database console is sufficient for that v1 workflow.
* Claim resolution: the host app exposes the same exact actions already defined in the stage/admin action contract: `check` and `resolve`. Any confirmation needed is handled inline or in the action flow, not by adding a new app-wide review screen unless it becomes necessary.
* Required status: `game_state`, `game.claiming_uid`, current player count, and the current card/round status are the only host-visible status fields needed in v1.
* Recovery: the host app has no internal state that is not recoverable from Firebase. It should rehydrate from the database on reload/restart and remain intentionally thin.
* Claim resolution: execute the action directly once the state is in the expected phase. If testing exposes a UX problem, Claude can ask for a confirmation tweak during implementation rather than preemptively adding a dedicated review screen.

### App purpose

* Allows the host to control the flow of the game outside of the parts that flow automatically (dealing tablas, drawing cards, etc).
* Read the live Firebase state and allowing the host user to emit relevant admin actions without owning the game state machine.

### Runtime and auth

* Runtime: plain web is preferred for v1; Flutter web is acceptable but not required.
* Device target: mobile phone, optimized for a compact, portrait oriented control surface.
* Auth model: anonymous auth + UID display, then a person grants `isAdmin` via the bootstrap script.
* Admin setup: host UID is written to `admins/<uid>` with a simple `false` marker so it can be copied from the database during setup.

### Host console layout

This app is intentionally a single, compact control console for v1. It is not a multi-screen app; it is one status-and-actions view whose controls are enabled or disabled based on the current Firebase state.

#### Single console contents

Known UI elements:
* current `game_state` indicator
* current player count
* current claimant (`game.claiming_uid`)
* current card / round status
* action buttons for the currently valid host actions
* a small status strip showing the next thing to do for the current phase

The host UI should follow the same state model as the admin app:
* in `lobby`: show round setup controls and `next_game`
* in `dealing` or `drawing`: show draw/pause controls and status
* in `claiming`: show `check` and current claim details
* in `checking`: show the single `resolve` action
* in other phases: keep the UI minimal and display only the current state plus any obvious next action

This is intentionally simple: no separate screens, no fancy navigation, and no hidden local state beyond transient UI wiring.

### Action contract

Every host control writes a single action name via Firebase `push()` under `/actions/<pushid>`. The value written is the action string itself.

Valid actions in v1:
* `next_game`
* `start_drawing`
* `pause`
* `resume`
* `check`
* `resolve`

Example:
* button label: `pause`
* write: `/actions/<pushid>` = `"pause"`

### Data contract

#### Reads

* `game_state`
* `game.claiming_uid`
* `players` (count and basic status)
* current card / draw state if needed for the screen

#### Writes

* action writes only, no persisted host-local state

#### Local-only state

* transient UI state only
* current selected action or confirmation moment
* small in-memory values needed for the current screen

### Implementation slices

* H1: app shell + auth + UID display
* H2: Firebase read subscriptions and status panel
* H3: action buttons and action dispatch
* H4: claim resolution view
* H5: restart/reload recovery and final QA

### Test plan scaffold

* Phase 1: manual Firebase state injection for each host state.
* Phase 2: action-check verification for `next_game`, `start_drawing`, `pause`, `resume`, and claim resolution.
* Phase 3: restart/reload validation to confirm the host app rehydrates from Firebase without internal state.
* Phase 4: edge-case validation for invalid action timing and stale claim states.

### Claude handoff prompt (short)

```markdown
Build the host/remote-control app for Loteria based on the information in the spec.md and implementation-plan.md. Make it a single simple control console, not a multi-screen app.

Requirements:
- Read Firebase state and show: `game_state`, player count, current claimant, current card/round status.
- Use the exact action names as button labels: `next_game`, `start_drawing`, `pause`, `resume`, `check`, `resolve`.
- Each button writes a single action string via Firebase `push()` to `/actions/<pushid>`, e.g. `"pause"`.
- Keep all real game state in Firebase; do not store hidden local state for game logic or win detection.
- Do not add a stage display or extra screens.
- Use simple state-driven enable/disable logic based on `game_state`.
- Prefer minimal, working code over polish.
- Use plain web if easiest; Flutter web is acceptable.
- Auth can be anonymous for the session; admin access comes from the custom `isAdmin` claim.
```


## TODOs for v2

[*] In the *stage view* during `lobby`, show the "LOTERIA` label at the bottom, over the `cta.png` image, show the URL above the QR code, and the number of players under it.
[*] While in the lobby, waiting for the game to start, the *player app* should show cards flying over the screen, similar to the *stage view*. -- implemented 2026-09-10.
[*] In the *stage view* during `dealing` after dealing all tablas, show a throbbing "Ready to play" label below the count.
[*] The *player app* should always show the UID, even during play. It looks like next to the "winning layout" there is enough space for this. -- implemented 2026-09-10.
[*] In the *stage view* during `celebrate`, show beans on the cards of the winning line/shape that the player completed. If there are multiple such lines/shapes, put beans on all of them. It might also be worth outlining the winning cards on the tabla. -- implemented 2026-09-10; upgraded to a bold pulsing border/glow + scaling bean same day, static border was too subtle.
[*] On the main screen of the stage view (drawing, pause, etc), we should show the count of active players and the number of blocked players: "<x> active players, <y> blocked". For the count of active players, we should count the `players/<uid>` values for which the UID also exists in `lobby/<uid>`. For the blocked player count, count the `blocked_uids/<uid>` values for which the UID also exists in `lobby/<uid>`. -- implemented 2026-09-10.
[*] We should introduce settings, stored in the database, set from the remote control/host view, and used by the app. To begin with, we should have:
  * `sound`: `on`|`off` (default: `"on"`) to control whether the audio plays back in the *stage view*
  * `max_player_count`: <number> (default: `1000`) to control the maximum number of players that are copied by the admin process from the lobby to the new game.
  * `draw_interval`: <number> (default: `5000`) the interval at which new cards are drawn by the admin process
  -- implemented 2026-09-10.