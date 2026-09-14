# Product Specification: Multiplayer Lotería for Conferences

## 1. System Overview
* **Goal**: A real-time, mass-multiplayer Lotería game where an audience at a conference plays on their phones while tracking a central card-drawing screen on a stage projector.
* Inspired by this [Google Doodle](https://doodles.google/doodle/celebrating-loteria/) from 2019.
* **Target Stack**: Flutter (or Web/tldraw-scripted frontend) with a Firebase backend (RTDB or Firestore TBD).
* **Network Context**: Local room scaling (dozens to hundreds of concurrent connections).

## 1a. Ideas

* Can we run a local mesh network, to show how you can bypass the dreaded conference wifi? This would require everyone to install a native app, which seems unlikely.
* Can we run this as a custom wifi network, so where I run an ad-hoc network on a custom device I bring (a Pi or something) and the players connect to that network and automatically get the (web) client? For more on this, see [section 7](#7-idea-captive-portal--automated-onboarding)

## 2. Architecture & View Separation
The application serves three distinct user experiences driven by a single game state.

### A. Stage View (Projector)
* **Route**: `/?view=stage` or `/stage`
* This process runs the presentation that's projected to the big screen, but it also runs the backend game/admin actions (triggered by host actions and player writes into the database).
* **UI Elements**:
    * Large display of the current drawn card (e.g., "El Catrín").
    * History log of the last 4 drawn cards.
    * Real-time leaderboard or active player count.
    * A QR code and short URL (`http://<ip>:3210/?view=player`) for audience onboarding.

### B. Player View (Mobile Web/App)
* **Route**: `/?view=player` or `/player`
* **UI Elements**:
    * A randomized 4x4 grid (Tabla) generated uniquely for each player upon joining.
    * Interactive tokens (beans) that players tap to place on matching cards.
    * A prominent "¡LOTERÍA!" button that unlocks only when a winning pattern is completed.

### C. Host View (Mobile Web)
* **Route**: `/?view=host` or `/host`
* The game host (puf) will open this view on their phone, not showing it to the players/audience.
* This route requires some form of authentication/authorization, just to prevent people from trying to hack it. Note: all data manipulation will actually be checked in the security rules of the database, so this is just an extra check whether to even show the UI or not. We'll iron out details in future phase.
* We'll want to store any authorization state in local storage or a cookie.
* Authorization for the rules will be done in the backend (database rules), but it's still good to hide this UI.
* The host view sends actions to the game admin process by writing them to (a protected location of) the database.
* These (host to admin) actions include `action`, `actor_uid`, `request_id`, and `timestamp` properties.
* **UI Elements**:
    * The elements of the Host UI are called out below in section 3.

## 3. Core Game Loop & State Machine

### state: `lobby`

The app starts with a lobby, where players can join a game before it starts. Any player (who has loaded the app and is signed in) automatically joins the game. At this point the stage view shows how players can join, and any already joined player screens show "Waiting for next game".

Note: if a player loads and signs in to the app while a game is in progress, they'll remain in the "Waiting for next game" screen until the time the state is `lobby`.

The host can at any point start the game (action: `next_game`), at which point the admin process picks a random game id (the seed), writes that to the database, copies the player IDs from the lobby to the `players` area of the database, and starts dealing tablas (state: `dealing`).

* Stage view
  * Show an explanation of what the game is
  * Show how to join (via a URL and/or QR code)
  * Number of players currently connected
* Player view
  * When not signed in: sign-in screen
  * When signed in: "Waiting for next game to start", their UID (maybe with a QR code I can scan in the Host view)
* Host view
  * Player count
  * "Start game" button

### state: `dealing`

The admin process determines the winning pattern for the game (from the seed). The options are: Four in a row (horizontal, vertical, or diagonal). Four Corners: The four outer corner squares of the board. El Pozo (Square): A tight 2x2 square block of four adjacent tokens.

The admin process loops through the registered players, and for each generates a tabla card (from the seed), and writes that `tabla_id` to the player's part of the database.

The stage shows how many players got their tabla already and how many are in the game in total: "Dealing tabla %d of %d". It can show a quick animation of each card being "handed out".

While waiting for a tabla the player app shows a "Waiting for tabla" label. Once it has received the tabla it shows a grayed out tabla, with a "Waiting to start" label over it.

Once all tablas are dealt, the host can start the drawing of cards (action: `start_drawing`), at which point the game admin process sets the state: `drawing`, which starts drawing cards.

### state: `drawing`

Each N seconds (5 or so) a (non-duplicate) card_id is drawn, and written to the database. This new card is displayed on the Stage view with an animation, and the name of the card is played on audio (see Google Doodle for sounds style).

A progress bar may mark the passage of time between the card drawings.

Each card can only be drawn once (as it's a deck). If the deck ever becomes empty, that is shown to the host, who can start a new game by clicking `next_game` (At which point the admin process clears `players` and possibly `blocked_uids`, and sets the game state back to `lobby`).

While drawing cards, the host can `pause` and `resume` the drawing (to allow for banter). This action *is* written to the database, but does not change the game state.

Each player can put beans on their tabla by either dragging a bean from the container onto any cell on their tabla, or by clicking a cell on their tabla. This is pure client-side UI, so not written to the database. They have an infinite number of beans.

A player can claim ¡Loteria! (action: `loteria`), which writes their player ID to the global `claiming_uid` property. This write only succeeds if there is currently no value in the property and if the player ID is not in `blocked_uids`. The admin process then puts the game state into `claiming` (which pauses card drawing).

While a `claiming_uid` is present in the database, the Stage view shows a character somewhere on the screen.
While a `claiming_uid` is present in the database, drawing of cards is automatically paused (no state change needed).
While a `claiming_uid` is present in the database, the LOTERIA button is disabled for all players.


While the player's ID is in `claiming_uid`, the player screen flashes white (so that the host can tell them to hold up their phone and show it).

### state: claiming

The admin process looks up the `tabla_id` of the `claiming_uid` and checks if the loteria claim is `accepted` or `rejected`. It appends these values and the `game_id` to an append-only `claim_log` place in the database.

The Host view shows the (most recent) `claiming_uid`, the `tabla_id` (or the actual tabla visually) and whether the claim was `accepted` or `rejected`.

If this is the first claimant for this game *or* if the claim is valid, the Host view can trigger a `check` action, for which the admin process then changes the state to `checking`. Otherwise the admin process adds the `claiming_uid` to `blocked_uids` list, and clears the `claiming_uid`.

So: only the first invalid claim in a game is escalated to a stage-visible false-claim flow. Subsequent invalid claims are rejected silently (no stage false-claim animation) by adding the `claiming_uid` to `blocked_uids`, clearing claiming_uid, and returning to the `drawing` state.

### state: checking

1. The host tells the player to hold up their phone. One screen flashes white.
2. The host clicks the single `resolve` action.
3. The admin process finalizes the claim as either `winner` or `cheater` based on the host decision.

### state: cheater

The stage view shows a "false bingo" animation.

The admin process counts down from 5 or 10, adds the `claiming_uid` to `blocked_uids`, and then clears the `claiming_uid`, and sets the state back to `drawing`.

### state: winner

The admin process writes the `claiming_uid`, the `tabla_id`, and the `game_id` to an append-only location `winner_log` in the database, and sets the game state to `celebrate`

### state: celebrate

The Stage view shows that there was a winner, and animations of fireworks and Loteria cards.

The Player views of non-winning players show "Great game! Sorry that you didn't win."

When the host clicks `next_game`, the admin process clears `players` and possibly `blocked_uids`, and sets the game state back to `lobby`.

## States, actions, and transitions

This section is a compact cross-check of Section 3 narrative flow.

### Primary flow transitions

| State | Trigger | Actor | Next | Notes |
| --- | --- | --- | --- | --- |
| lobby | next_game | host view | dealing | admin process creates `game_id`, snapshots players, starts dealing |
| dealing | start_drawing | host view | drawing | only after all tablas are assigned |
| drawing | loteria | player | claiming | claim only accepted if `game_state` is `drawing`, `claiming_uid` is empty, and player UID is not in `blocked_uids` |
| drawing | pause | host | paused | host action to pause drawing of cards |
| paused | resume | host | drawing | host action to resume drawing of cards |
| claiming | check | host view | checking | claim is valid, or this is the first invalid claim in the game (stage-visible false-claim flow) |
| claiming | auto_reject_claim | admin process (stage) | drawing | claim is invalid and not the first invalid claim in the game (silent reject path): append rejected outcome to `claim_log`, add UID to `blocked_uids`, clear `claiming_uid` |
| checking | resolve | host view | winner or cheater | host finalizes the claim outcome as either a winner or a cheater |
| cheater | timeout_elapsed | admin process (stage) | drawing | add UID to `blocked_uids`, then clear `claiming_uid` after countdown |
| winner | finalize_winner | admin process (stage) | celebrate | append `winner_log` entry |
| celebrate | next_game | host view | lobby | clears `players` and possibly `blocked_uids`, and sets the game state back to `lobby` |

### Rejected actions (explicit)

* In `dealing`, reject `start_drawing` if not all tablas are assigned.
* In `drawing`, reject `resolve` because resolving is only valid in `checking`.
* In `checking`, reject additional `loteria` claims while a claim is already being resolved.
* In `lobby`, reject `pause` because drawing is not active.

### Continuous behavior

* In `drawing`, the admin process emits a timed `draw_tick` while not paused and while cards remain.
* `pause` and `resume` do not change state; they only gate timed draws in the admin process.

## 4. Database design

We'll (very likely) use the Firebase Realtime Database for this app, since it has a good free tier, and we can use its presence feature.

This section intentionally defines only the starter database shape.

* `game_state`: top-level state value (`lobby`, `dealing`, `drawing`, `claiming`, `checking`, `cheater`, `winner`, `celebrate`)
* `game`: single active game object (`game_id`, `claiming_uid`, pause flag, draw metadata)
* `lobby/<uid>`: where each player tracks their presence (with a Firebase Realtime Database [presence handler](https://firebase.google.com/docs/database/flutter/offline-capabilities#section-presence))
* `players/<uid>`: per-player data for the active game (`tabla_id`, participation flags)
* `blocked_uids/<uid>`: blocklist (currently permanent, if we make this for the active game only, we'll merge `players` and `blocked_uids` under a common `current_game` node)
* `actions/<request_id>`: host action requests (`next_game`, `start_drawing`, `pause`, `resume`, `check`, `resolve`)
* `claim_log/<event_id>`: append-only claim events for the active game (`game_id`, `tabla_id`, `player_uid`, `result`: (`accepted`|`rejected`))
* `winner_log/<event_id>`: append-only winner events for the active game (`game_id`, `tabla_id`, `player_uid`)

If there is no active game, `game_state` is `lobby` and `game` can be empty or absent.

### Securing the database

The database will be secure with Firebase Realtime Database security rules.

The host (identified by their UID) can read/write everything in the database.

Players can only:
* Read the top-level `game_state`
* Read the top-level `game` object
* Read the `players/<uid>` where `uid` matches their (Firebase Authentication) UID
* Read `blocked_uids/<uid>` where `uid` matches their (Firebase Authentication) UID
* Write `true` to `lobby/<uid>` where `uid` matches their (Firebase Authentication) UID
* Write their (Firebase Authentication) UID to `game/claiming_uid`, when:
  * there is currently no data in that path, and 
  * their UID does not exist under `blocked_uids/<uid>`, and
  * the current `game_state` is `drawing`

## 5. Dirty Restart / Recovery Concerns

Because the game state is persisted in Firebase, a simple browser reload or process restart does not by itself lose the game state. However, there are still several recovery questions that need explicit design.

These are concerns to resolve later, not decisions:

* **Stage authority resumption**: If the stage view process reloads or restarts, how does it recognize that it is resuming responsibility for the admin process for the current game, rather than accidentally starting duplicate admin behavior?
* **Host view resumption**: If the Host view reloads or reconnects mid-game, what information must it reconstruct from the database so that its controls and status indicators match reality immediately?
* **Drawing timer resumption**: If the stage process dies and comes back while the game is in `drawing`, what exactly should happen to the cadence of card draws, the progress bar, and any pending delayed transitions?
* **Paused game recovery**: If the system restarts while drawing is paused, what persisted state is required so every view can tell that the game is paused and not merely idle or disconnected?
* **In-flight claim recovery**: If the stage process or Host view disappears while the game is in `claiming` or `checking`, how do we recognize that the game is waiting on a human decision rather than actively drawing cards?
* **Stuck state detection**: A persisted state can still be invalid operationally. For example, the database may say `checking` forever even though no operator is actively resolving it.
* **Action replay / duplication**: After reconnects, retries, or double taps, the system may receive repeated host or player actions. We need to define which actions are idempotent and which must be rejected once already applied.
* **Partial write recovery**: Some transitions touch multiple fields. If the admin process crashes mid-transition, we need to understand what partially-written states are possible and how they should be recognized.
* **Stage/Host disagreement**: After reconnects, the stage view and Host view may briefly disagree about the latest claim, pause status, or winner state until they catch up with the persisted data.
* **Player resumption semantics**: If a player reloads during `dealing`, `drawing`, `claiming`, or `celebrate`, we need to define exactly what they reconstruct from persisted state and what remains intentionally client-local.
* **End-of-deck recovery**: If all cards have already been drawn and the stage process restarts, the resumed system must still be able to tell whether the game is over, waiting on a claim, or needs some other terminal handling.


## 7. Idea: Captive Portal & Automated Onboarding

Note: we did not yet decide to implement this, so this section is just for brainstorming.

Modern keyboard-less devices often use a captive portal to handle their onboarding. For example, to configure a Picpak e-ink device, I connect my phone or laptop to the `picpak-setup` wifi and that then shows a web portal for the setup.

### A. Infrastructure Requirements
* **Access Point (AP)**: The Raspberry Pi uses `hostapd` to broadcast an open, password-free Wi-Fi network (SSID: "Conference-Loteria").
* **DHCP & DNS**: `dnsmasq` manages IP assignments and routes all external DNS queries (`*`) straight back to the Pi's local IP address (e.g., `192.168.4.1`).

### B. Captive Portal Trigger Logic
To force the phone's native "Sign in to Wi-Fi network" screen to launch automatically, the server must intercept specific vendor detection URLs and respond with a `302 Redirect` or an HTTP 200 containing the client app.
* **Apple (iOS/macOS)**: Intercept requests to `://apple.com` and return the player view.
* **Android / Google**: Intercept requests to `://gstatic.com` or `://googleapis.com` and redirect to the player view.
* **Windows**: Intercept `://msftconnecttest.com`.

### C. Web Server Behavior for Captive Portals
* **Root Fallback**: Any HTTP request arriving at the server that does not match a static asset must default to serving `index.html` with `?view=player`.
* **Asset Optimization**: The entire player view (HTML, JS, CSS, images) must be bundled tightly and lightweight. Captive portal browsers have limited memory and may strip out advanced browser APIs or strict storage permissions.
* **No External Dependencies**: The frontend code cannot call any external CDNs (like Google Fonts or unpkg). All libraries and game assets must live entirely on the Pi's local storage.
