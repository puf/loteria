import { getApps, initializeApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';
const PROJECT_ID = 'lalotteria';
const DATABASE_URL = 'https://lalotteria-default-rtdb.firebaseio.com';
if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID, databaseURL: DATABASE_URL });
const db = getDatabase();
await db.ref().update({ game_state: 'lobby', game: null, lobby: { p1: true, p2: true, p3: true }, players: null, actions: null, blocked_uids: null });
console.log('seeded lobby with 3 players');
process.exit(0);
