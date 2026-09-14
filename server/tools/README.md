# Admin tools

One-off Firebase Admin SDK scripts. Not part of the Flutter stage/admin app;
these run locally, once per admin, from a trusted machine.

## Setup

```bash
cd tools
npm install
```

## Granting admin access

1. Have the person sign in to the stage/admin app once (Sign in with
   Google) so their account exists in this Firebase project's Auth.
2. Get credentials for the Admin SDK -- either:
   - `gcloud auth application-default login` (needs Editor/Owner on the
     `lalotteria` GCP project), or
   - set `GOOGLE_APPLICATION_CREDENTIALS` to a service account key JSON
     (Firebase Console > Project settings > Service accounts > Generate
     new private key).
3. Run:
   ```bash
   node grant_admin_claim.mjs --email=host@example.com
   ```
4. Tell them to sign out and back in to the stage/admin app (or use its
   "Recheck admin access" action).
