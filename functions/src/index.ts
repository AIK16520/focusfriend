import * as admin from "firebase-admin";
admin.initializeApp();

export { onSessionCreated, onUnlockRequested } from "./notifications";
