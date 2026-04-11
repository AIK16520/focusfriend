import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

async function getTokensForUIDs(uids: string[]): Promise<string[]> {
  const docs = await Promise.all(
    uids.map((uid) => getFirestore().collection("users").doc(uid).get())
  );
  return docs
    .map((doc) => doc.data()?.fcmToken as string | undefined)
    .filter((t): t is string => !!t);
}

export const onSessionCreated = onDocumentCreated(
  "lockSessions/{sessionId}",
  async (event) => {
    const session = event.data?.data();
    if (!session || session.status !== "pending") return;

    const friendUIDs: string[] = session.friendUIDs ?? (session.friendUID ? [session.friendUID] : []);
    const tokens = await getTokensForUIDs(friendUIDs);
    if (tokens.length === 0) return;

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: `${session.ownerName} is now locked 🔒`,
        body: "They'll notify you when they want to unlock.",
      },
      data: { sessionId: event.params.sessionId, type: "session_pending" },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
  }
);

export const onUnlockRequested = onDocumentUpdated(
  "lockSessions/{sessionId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "unlockRequested") return;

    const friendUIDs: string[] = after.friendUIDs ?? (after.friendUID ? [after.friendUID] : []);
    const tokens = await getTokensForUIDs(friendUIDs);
    if (tokens.length === 0) return;

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: `${after.ownerName} wants to unlock 🔓`,
        body: "Tap to approve or deny their unlock request.",
      },
      data: { sessionId: event.params.sessionId, type: "unlock_requested" },
      apns: { payload: { aps: { sound: "default", badge: 1, "content-available": 1 } } },
    });
  }
);
