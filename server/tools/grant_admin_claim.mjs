#!/usr/bin/env node
// A0: Firebase Admin bootstrap script (implementation-plan.md "Decisions":
// "admin access is granted through a custom `isAdmin` claim assigned by a
// Firebase Admin SDK script"). This is the ONLY way a user becomes an admin
// -- the stage/admin app itself never grants this to anyone; it only reads
// the claim (see ../lib/services/auth_service.dart).
//
// One-time, per-admin use. Run it once for each person who should be able
// to run the stage/admin app.
//
// SHARED: the claim key ("isAdmin") is a cross-app contract with the
// Firebase security rules that will eventually gate admin-only paths using
// `auth.token.isAdmin` (spec.md section 4) -- don't rename it here without
// updating those rules too.
//
// Usage:
//   node grant_admin_claim.mjs --email=host@example.com
//   node grant_admin_claim.mjs --uid=<firebase-auth-uid>
//
// Requires Firebase Admin SDK credentials, via ONE of:
//   - `gcloud auth application-default login` (interactive; needs an
//     account with Editor/Owner on the `lalotteria` GCP project), or
//   - GOOGLE_APPLICATION_CREDENTIALS env var pointing at a service account
//     key JSON (Firebase Console > Project settings > Service accounts >
//     Generate new private key).
//
// The target user must already exist in Firebase Auth for this project --
// i.e. they must have signed in to the stage/admin app at least once
// (Sign in with Google) before you run this script for them.

import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const PROJECT_ID = 'lalotteria';

function parseArgs(argv) {
  const args = {};
  for (const raw of argv) {
    const match = /^--([^=]+)=(.*)$/.exec(raw);
    if (match) args[match[1]] = match[2];
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.uid && !args.email) {
    console.error('Usage: node grant_admin_claim.mjs --email=<email> | --uid=<uid>');
    process.exitCode = 1;
    return;
  }

  if (getApps().length === 0) {
    initializeApp({ projectId: PROJECT_ID });
  }
  const auth = getAuth();

  const user = args.uid
    ? await auth.getUser(args.uid)
    : await auth.getUserByEmail(args.email);

  const claims = { ...(user.customClaims ?? {}), isAdmin: true };
  await auth.setCustomUserClaims(user.uid, claims);

  console.log(`Granted isAdmin to ${user.email ?? '(no email)'} (uid: ${user.uid}).`);
  console.log(
    'They must sign out and back in to the stage/admin app (or use its ' +
      '"Recheck admin access" action) for the new claim to take effect -- ' +
      'a custom claim only appears in a freshly issued ID token.',
  );
}

main().catch((err) => {
  console.error('Failed to grant isAdmin claim:', err.message);
  process.exitCode = 1;
});
