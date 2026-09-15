// patch-plans/002-stress-test-deployed-app.md: drives the full lobby ->
// dealing -> drawing -> claim -> check -> resolve -> celebrate -> next_game
// flow against the *live* project with N scripted virtual players, to
// check the deployed app + new security rules hold up under load within
// the Spark plan's 100-simultaneous-connection ceiling.
//
// Virtual players go through the REST API as genuine non-admin clients
// (so they're actually bound by the player-facing security rules, not
// bypassing them the way the Admin SDK does) -- including holding a real
// streamed connection open for the run's duration, the same way a
// real client's live listener would, so this actually exercises the
// connection-count limit and not just one-shot writes. Admin-side actions
// (next_game, start_drawing, check, resolve) go through the Admin SDK
// directly, same as the other tools/ scripts -- driving the *real* admin
// engine running in a live stage-app tab, just automating the trigger
// side instead of clicking through the host UI for every run.
//
// Usage: node stress_test.mjs --players=10
//
// Requires: a stage-app tab open and connected (processes the pushed
// actions) -- this script only pushes/observes, it doesn't run the admin
// engine itself.

import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getDatabase } from 'firebase-admin/database';

const PROJECT_ID = 'lalotteria';
const DATABASE_URL = 'https://lalotteria-default-rtdb.firebaseio.com';
const API_KEY = 'AIzaSyBcn1iDxE_2_Cnzy0_o6p27qxZS8sFD89Y';
const REFERER = 'https://lalotteria.web.app/'; // matches the deployed origin's API key allowlist entry

if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID, databaseURL: DATABASE_URL });
const adminDb = getDatabase();

function parseArgs(argv) {
  const args = {};
  for (const raw of argv) {
    const m = /^--([^=]+)=(.*)$/.exec(raw);
    if (m) args[m[1]] = m[2];
  }
  return args;
}

async function signUpAnonymous() {
  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Referer: REFERER },
    body: JSON.stringify({ returnSecureToken: true }),
  });
  if (!res.ok) throw new Error(`signUp failed: ${res.status} ${await res.text()}`);
  const data = await res.json();
  return { uid: data.localId, idToken: data.idToken };
}

async function restPut(path, idToken, value) {
  const res = await fetch(`${DATABASE_URL}/${path}.json?auth=${idToken}`, {
    method: 'PUT',
    headers: { Referer: REFERER },
    body: JSON.stringify(value),
  });
  return { status: res.status, body: await res.text() };
}

// Opens a real streamed connection (matches what a live client listener
// holds open) and just leaves it open -- returns an AbortController so it
// can be torn down in cleanup. Errors here are collected, not thrown, so
// one flaky connection doesn't abort the whole run.
function openStreamedConnection(path, idToken, errors) {
  const controller = new AbortController();
  fetch(`${DATABASE_URL}/${path}.json?auth=${idToken}`, {
    headers: { Accept: 'text/event-stream', Referer: REFERER },
    signal: controller.signal,
  })
    .then(async (res) => {
      if (!res.ok) {
        errors.push(`stream ${path}: ${res.status}`);
        return;
      }
      // Drain the stream in the background so the connection stays open;
      // ignore the actual event content, this is purely load.
      const reader = res.body.getReader();
      try {
        while (true) {
          const { done } = await reader.read();
          if (done) break;
        }
      } catch {
        // Aborted on cleanup -- expected, not an error.
      }
    })
    .catch((err) => {
      if (err.name !== 'AbortError') errors.push(`stream ${path}: ${err.message}`);
    });
  return controller;
}

async function waitFor(path, predicate, { timeoutMs = 30000, pollMs = 300 } = {}) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const snap = await adminDb.ref(path).get();
    const value = snap.val();
    if (predicate(value)) return { value, elapsedMs: Date.now() - start };
    await new Promise((r) => setTimeout(r, pollMs));
  }
  throw new Error(`waitFor(${path}) timed out after ${timeoutMs}ms`);
}

async function pushAction(name) {
  await adminDb.ref('actions').push(name);
}

async function runOnce(n) {
  const errors = [];
  const players = [];
  const controllers = [];
  const result = { n, errors, timings: {} };

  console.log(`\n=== N=${n} ===`);

  // 1. Reset to a clean lobby.
  await adminDb.ref().update({
    game_state: 'lobby',
    game: null,
    lobby: null,
    players: null,
    blocked_uids: null,
    actions: null,
  });

  // 2. Create N virtual players, each joining the lobby as a real
  // non-admin client (rule-gated write) and holding a streamed
  // connection open for the rest of the run.
  const joinStart = Date.now();
  for (let i = 0; i < n; i++) {
    const player = await signUpAnonymous();
    const write = await restPut(`lobby/${player.uid}`, player.idToken, true);
    if (write.status !== 200) errors.push(`lobby write for ${player.uid}: ${write.status} ${write.body}`);
    controllers.push(openStreamedConnection(`players/${player.uid}`, player.idToken, errors));
    players.push(player);
  }
  result.timings.joinMs = Date.now() - joinStart;
  console.log(`joined lobby: ${n} players in ${result.timings.joinMs}ms, ${errors.length} errors so far`);

  // 3. next_game -> dealing, wait for all N tablas.
  await pushAction('next_game');
  const dealt = await waitFor(
    'players',
    (v) => v && Object.keys(v).length >= n,
    { timeoutMs: 60000 },
  );
  result.timings.dealingMs = dealt.elapsedMs;
  console.log(`dealt ${n} tablas in ${dealt.elapsedMs}ms`);

  // 4. start_drawing, sample the first few draw intervals for cadence.
  await pushAction('start_drawing');
  const drawSamples = [];
  let lastCount = 0;
  let lastTime = Date.now();
  for (let i = 0; i < 3; i++) {
    const r = await waitFor('game/draw_count', (v) => (v ?? 0) > lastCount, { timeoutMs: 15000 });
    drawSamples.push(Date.now() - lastTime);
    lastTime = Date.now();
    lastCount = r.value;
  }
  result.timings.drawIntervalsMs = drawSamples;
  console.log(`draw cadence samples: ${drawSamples.join(', ')}ms`);

  // 5. Jump draw_count to (near) full deck so a claim is trivially valid
  // -- this test is about load/correctness, not a realistic win timing
  // (see patch-plans/002's own note on this).
  await adminDb.ref('game/draw_count').set(54);

  // 6. Winner claims for real, through the actual rule-gated write.
  const winner = players[0];
  const claimStart = Date.now();
  const claimWrite = await restPut('game/claiming_uid', winner.idToken, winner.uid);
  if (claimWrite.status !== 200) errors.push(`claim write: ${claimWrite.status} ${claimWrite.body}`);
  await waitFor('game_state', (v) => v === 'claiming', { timeoutMs: 10000 });

  // 7. check -> checking -> resolve -> celebrate.
  await pushAction('check');
  await waitFor('game_state', (v) => v === 'checking', { timeoutMs: 10000 });
  await pushAction('resolve');
  await waitFor('game_state', (v) => v === 'celebrate', { timeoutMs: 10000 });
  result.timings.claimToCelebrateMs = Date.now() - claimStart;
  console.log(`claim -> celebrate in ${result.timings.claimToCelebrateMs}ms`);

  // 8. Reset back to lobby.
  await pushAction('next_game');
  await waitFor('game_state', (v) => v === 'lobby', { timeoutMs: 10000 });

  // Cleanup: close streamed connections, delete the virtual auth users.
  for (const c of controllers) c.abort();
  const auth = getAuth();
  await Promise.all(
    players.map((p) => auth.deleteUser(p.uid).catch((e) => errors.push(`deleteUser ${p.uid}: ${e.message}`))),
  );
  await adminDb.ref().update({ game_state: 'lobby', game: null, lobby: null, players: null });

  console.log(`N=${n} done, ${errors.length} error(s)`);
  if (errors.length) console.log(errors.slice(0, 10));
  return result;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const n = parseInt(args.players ?? '5', 10);
  const result = await runOnce(n);
  console.log('\n--- summary ---');
  console.log(JSON.stringify(result, null, 2));
  process.exit(result.errors.length ? 1 : 0);
}

main().catch((err) => {
  console.error('Stress test failed:', err);
  process.exitCode = 1;
});
