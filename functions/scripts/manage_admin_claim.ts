import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

type Action = "grant" | "revoke";

function usage(): never {
  throw new Error(
    "Usage: npm run admin:claim -- grant|revoke authorized.account@gmail.com"
  );
}

async function main(): Promise<void> {
  const [action, email, ...extra] = process.argv.slice(2);
  if (
    extra.length > 0 ||
    (action !== "grant" && action !== "revoke") ||
    !email ||
    !email.includes("@")
  ) {
    usage();
  }

  if (getApps().length === 0) initializeApp();
  const auth = getAuth();
  const user = await auth.getUserByEmail(email);
  const claims = {...(user.customClaims ?? {})};
  if (action === "grant") {
    claims.admin = true;
  } else {
    delete claims.admin;
  }
  await auth.setCustomUserClaims(user.uid, claims);
  console.log(`Admin claim ${action === "grant" ? "granted" : "revoked"}.`);
}

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : "Unable to manage admin claim.");
  process.exitCode = 1;
});
