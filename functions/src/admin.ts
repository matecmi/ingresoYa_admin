import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

if (getApps().length === 0) initializeApp();

export const db = getFirestore();

/** All persisted event times must be resolved by Firestore, never by a client clock. */
export const serverTimestamp = (): FieldValue => FieldValue.serverTimestamp();
