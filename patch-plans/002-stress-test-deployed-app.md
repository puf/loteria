# Stress test the deployed app

Not yet executed -- Frank wants a few manual test runs on the deployed version first.

## Goal

Confirm the live Hosting + RTDB setup (player app + host app, new security rules) holds up with realistic player counts, before ever running this at a real event. Cover connection load and full-flow correctness together, not just raw throughput.

## Constraint: Spark plan connection cap

`lalotteria` is on the free Spark plan: **100 simultaneous RTDB connections**, hard cap. Every open tab/script holds one connection for as long as it's connected -- so the actual player-count ceiling for a test run is under 100, once the stage tab, host tab, and my own observer tab(s) are counted. Test matrix below tops out at ~90 simulated players for that reason, not 100.

## What "Claude stress tests" means here

I can't realistically open 100 real browser tabs through the Browser pane -- a handful is already the practical limit. Two-pronged approach instead:

1. **Scripted virtual players** (Node, using the Firebase JS SDK or plain REST against the *live* project) -- each one signs in anonymously, writes its own `lobby/<uid>` presence, waits for `players/<uid>` to appear once dealt, and otherwise just holds its connection open like a real idle player would. This is what actually generates the connection/write load the rules and the admin engine have to handle.
2. **A few real Browser-pane tabs** (stage view + 1-2 "player" tabs) running alongside the virtual players, so I can visually confirm nothing looks broken or laggy from a real client's perspective while the load is happening -- dealing animation, draw pace, claim flow.

One virtual player is designated the "winner": once `game_state` is `drawing`, it waits until `draw_count` is high enough that any pattern is trivially satisfied (full or near-full deck -- simplest way to get a valid claim without precomputing a minimal win, since this test is about load, not about a realistic win timing) and then performs the real conditional `game/claiming_uid` write, so the whole claim -> check -> resolve -> celebrate -> next_game path gets exercised under load too, not just dealing/drawing.

## Test matrix

Run the full flow (lobby -> next_game -> dealing -> start_drawing -> drawing -> claim -> check -> resolve -> celebrate -> next_game) at each of: **5, 10, 25, 50, ~90** virtual players. Reset cleanly (`next_game` abort or a full DB reset) between runs.

## Metrics to capture per run

- **Dealing duration**: time from `next_game` click to the last tabla dealt. `admin_engine.dart`'s `_dealPaceFor` already targets ~10-15s total regardless of player count (ramped, capped) -- this is the main thing to empirically confirm actually holds at the higher counts, not just in theory.
- **Draw loop cadence**: should be completely unaffected by player count (single admin-side loop, not fanned out per player) -- confirm draw_count still advances on the configured interval.
- **Errors**: any permission-denied / rule rejections that shouldn't happen (would indicate a rules bug at scale, not just at N=1), any dropped/failed writes.
- **Responsiveness**: stage and host apps stay visually smooth and interactive throughout, not just correct.
- **Actual peak connection count** vs the 90 target (worth spot-checking there's no unexpected multiplier -- e.g. a client opening more than one connection).

## Cleanup

- Reset `lobby`/`players`/`blocked_uids`/`game` after each run the same way the existing manual tests did.
- Virtual players are real (if throwaway) Firebase Auth anonymous users -- they accumulate in the project's Auth user list across runs. Plan for a cleanup pass at the end (Admin SDK `listUsers` + delete the ones created during this test window) rather than leaving hundreds of anonymous test accounts behind indefinitely.

## Open question for Frank

Do you want the "visual sanity check" tabs to include a real phone (not just the Browser pane), or is the Browser pane's view sufficient for this pass?
