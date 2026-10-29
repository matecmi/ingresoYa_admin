/* eslint-disable */
// Deja una cuenta de TEST sin datos (conserva el acceso de Firebase Auth).
// Uso: node tools/reset_user_test.js --email x@y.com [--apply]
// Sin --apply solo lista lo que borraría. Nunca corre fuera de TEST.
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { readBackendConfig } = require("../lib/src/config");

const arg = (name) => { const i = process.argv.indexOf(name); return i < 0 ? undefined : process.argv[i + 1]; };
const email = arg("--email");
const apply = process.argv.includes("--apply");
const projectId = "ingresoya-e5115";
if (!email) throw new Error("Falta --email");

initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();
const C = readBackendConfig({ INGRESOYA_ENV: "test" }).collections;

(async () => {
  const uid = (await getAuth().getUserByEmail(email)).uid;
  console.log("uid", uid);
  const refs = [];
  const userRef = db.collection(C.users).doc(uid);
  const subs = await userRef.listCollections();
  for (const s of subs) console.log("  perfil/", s.id, (await s.count().get()).data().count);
  if ((await userRef.get()).exists || subs.length) refs.push(["recursive", userRef]);
  const lb = db.collection(C.leaderboard).doc(uid);
  if ((await lb.get()).exists) refs.push(["doc", lb]);
  for (const [col, field] of [[C.attempts, "userId"], [C.aliases, "uid"], [C.purchaseTokens, "uid"], [C.purchaseTokens, "userId"]]) {
    const snap = await db.collection(col).where(field, "==", uid).get();
    snap.docs.forEach((d) => refs.push(["recursive", d.ref]));
  }
  for (const col of [C.leagueMembers, C.challengeEntries]) {
    const snap = await db.collection(col).get();
    snap.docs.filter((d) => d.id.endsWith(`_${uid}`)).forEach((d) => refs.push(["doc", d.ref]));
  }
  const counts = {};
  refs.forEach(([, r]) => { const c = r.parent.id; counts[c] = (counts[c] ?? 0) + 1; });
  console.log(counts);
  if (!apply) return console.log("(solo lista; usa --apply para borrar)");
  for (const [kind, r] of refs) kind === "recursive" ? await db.recursiveDelete(r) : await r.delete();
  console.log("borrado", refs.length);
})().catch((e) => { console.error(e); process.exit(1); });
