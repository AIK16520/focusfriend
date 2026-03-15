# [App Name TBD] — iOS App Knowledge Document
> Context document for Claude Code. Read this before writing any code for this project.

---

## What Is Ficus?

Ficus is an iOS focus app that locks your phone (or blocks specific apps) until a trusted friend gives you permission to unlock it. It's built around social accountability — the embarrassment of having to ask someone to let you back on Instagram is the whole point.

---

## Core Problem

Willpower-based focus apps fail because you can always override them yourself. Ficus removes that escape hatch by requiring another human to unlock you. The social cost of asking is the deterrent.

---

## Feature Roadmap (Build Order)

### Phase 1 — App Blocking (Investigate First)
**Task:** Verify what iOS actually allows before building anything.

Apple's APIs for app restriction are limited and sandboxed. Here's what exists:

| API | What It Does | Limitation |
|---|---|---|
| **Screen Time API (ManagedSettings)** | Block app categories, specific apps by bundle ID | Requires `FamilyControls` entitlement — only granted to parental control apps via Apple review |
| **FamilyControls framework** | Full Screen Time-style control | Requires device authorization via `AuthorizationCenter.shared.requestAuthorization(for: .individual)` — user must grant this explicitly |
| **DeviceActivityMonitor** | Monitor and respond to usage events | Works as an extension, not in-app |
| **ShieldConfiguration** | Customize the "blocked" screen users see | App extension only |

**Verdict:** Full app blocking IS possible without MDM if you use `FamilyControls` (iOS 15+). The user has to authorize the app once via Screen Time settings. This is the same path apps like Opal and Roots use.

**Entitlement required:** `com.apple.developer.family-controls` — must be requested from Apple at https://developer.apple.com/contact/request/family-controls-entitlement/

**Key frameworks:**
- `FamilyControls` — authorization
- `ManagedSettings` — apply/remove app blocks
- `DeviceActivityMonitor` — extension that enforces rules even when the app is backgrounded
- `ManagedSettingsStore` — persists block configuration

**Critical architecture note:** App blocking is enforced by a `DeviceActivityMonitor` app extension, not the main app. The extension runs independently even if the main app is killed. This is how the block survives.

---

### Phase 2 — Friend-Based Unlock System

#### Concept
- User sets a "lock" (selects apps to block + sets a session)
- A friend receives a push notification or deep link
- Friend taps "Unlock" → block is lifted
- Friend can also tap "Stay locked" to deny the request

#### Architecture

```
[User locks] → [Ficus backend receives lock event]
                        ↓
              [Push notification sent to Friend]
                        ↓
              [Friend approves or denies]
                        ↓
              [Backend sends unlock signal]
                        ↓
              [DeviceActivityMonitor extension lifts block]
```

#### Backend
- Use **Firebase** (Firestore + Cloud Messaging) for MVP
  - Firestore: store lock sessions, friend relationships, unlock requests
  - FCM: push notifications to friend's device
- Consider **Supabase** as an alternative if you want Postgres + realtime out of the box

#### Data Models

```
User {
  id: String
  displayName: String
  deviceToken: String  // FCM token
  friends: [FriendRef]
}

LockSession {
  id: String
  ownerId: String
  friendIds: [String]  // who can unlock
  lockedApps: [AppToken]  // ManagedSettings ApplicationToken
  status: "active" | "unlocked" | "expired"
  createdAt: Timestamp
  expiresAt: Timestamp?
  unlockRequestedAt: Timestamp?
  unlockedBy: String?
}
```

#### Friend Pairing
- Invite via deep link or QR code
- Friends must have Ficus installed to approve unlocks
- Start with 1 friend per session for MVP; expand to N friends later

#### Unlock Flow (Friend Side)
- Friend gets push notification: *"Ali wants to unlock his phone. Approve?"*
- Opens Ficus → sees session context (how long locked, what apps)
- Taps Approve → POST to backend → Firestore session updated → owner's device notified via FCM → `ManagedSettingsStore` clears the block

---

### Phase 3 — Failsafes (Because Friends Are Unreliable)

These exist because a friend might be asleep, out of signal, or just a chutiya.

#### Failsafe 1: Multiple Friends
- Assign 2+ friends to a session
- Any one of them can approve the unlock
- Useful when primary friend is MIA

#### Failsafe 2: Countdown Timer
- User sets a maximum lock duration at session start (e.g., "lock me for 2 hours")
- After timer expires, block lifts automatically — no friend needed
- Enforce via `DeviceActivitySchedule` in `DeviceActivityMonitor`
- Display countdown on lock screen widget (WidgetKit)

**Timer UX options:**
- Hard timer: just unlocks at T+X
- Soft timer: sends friend a "Time's almost up, extend?" prompt
- Shame timer: if you didn't finish your task and the timer ends, something embarrassing happens first

#### Failsafe 3: Task-Gated Unlock (Canvas Integration)
- User links their Canvas (LMS) account via OAuth
- Ficus polls Canvas API to check if a specific assignment has been submitted
- On submission detected → auto-unlock
- Canvas API endpoint: `GET /api/v1/courses/:id/assignments/:id/submissions/self`
- Requires Canvas OAuth token stored securely in Keychain

#### Failsafe 4: Shame Post
- If user bypasses the system or the lock expires without task completion, Ficus posts something embarrassing to their social media
- Platforms: Instagram Story, X/Twitter, Snapchat
- Implementation: user pre-writes the shame post text/image at session start, stored locally
- On shame trigger → share sheet opens automatically OR posts via API (Instagram Graph API requires business account; X API v2 works for posting)
- This is the nuclear option. Make it opt-in and very explicit.

---

## iOS Technical Stack

| Layer | Choice | Notes |
|---|---|---|
| Language | Swift | No Objective-C |
| UI | SwiftUI | Target iOS 16+ |
| App Blocking | FamilyControls + ManagedSettings | Requires Apple entitlement |
| Background Enforcement | DeviceActivityMonitor extension | Runs independently of main app |
| Push Notifications | FCM (Firebase Cloud Messaging) | Or APNs directly |
| Backend | Firebase (Firestore + Functions) | MVP choice |
| Auth | Firebase Auth | Phone number or Apple Sign In |
| Keychain | SwiftUI + Security framework | Store Canvas tokens etc. |
| Widgets | WidgetKit | Timer countdown display |

---

## App Extension Architecture

Ficus requires **two targets** in Xcode:

1. **Main App** — UI, session setup, friend management, settings
2. **DeviceActivityMonitor Extension** — enforces blocks, responds to unlock signals, lifts blocks when timer expires

These share an **App Group** container to pass data between them:
```swift
UserDefaults(suiteName: "group.com.yourapp.shared")
```

The extension cannot make network calls directly in all cases — use background tasks or rely on APNs-triggered updates.

---

## Permissions Required

| Permission | Why |
|---|---|
| FamilyControls authorization | To block apps |
| Push Notifications | Friend unlock flow |
| Network | Backend sync |
| Keychain access | Store tokens |
| App Group | Share state with extension |

---

## Competitive Landscape

| App | Approach | Gap This App Fills |
|---|---|---|
| Opal | Self-blocking, AI insights | No social accountability |
| Freedom | Cross-platform blocking | No human-in-the-loop |
| BeReal | Social accountability | Not for focus |
| Focusmate | Body doubling | No app locking |

Ficus's unique angle: **the unlock requires another human**. That social friction is the product.

---

## Open Questions / Decisions To Make

- [ ] Does the friend need Ficus installed, or can they unlock via web link? (Web = lower friction for onboarding friends)
- [ ] What happens if the user deletes the app while locked? (Blocks probably lift — test this)
- [ ] Should the session owner be able to see when friend viewed the notification? (Read receipts for accountability)
- [ ] Shame post: automated post or just "we'll open the share sheet" for the user to do manually?
- [ ] Monetization: free tier (1 friend, timer only) vs. paid (multiple friends, Canvas integration, shame post)?

---

## Dev Environment Notes

- Xcode 15+
- iOS 16+ deployment target
- FamilyControls entitlement must be approved by Apple before testing on real devices (simulator support is limited)
- Use a physical iPhone for all Screen Time API testing — the simulator does not accurately replicate blocking behavior
- Set up two Apple test accounts to simulate owner + friend flow

---

## Build Order Summary

1. Get FamilyControls entitlement approved + build app skeleton + DeviceActivityMonitor extension + test basic blocking on device
2. Firebase setup + friend pairing via deep link + push notification unlock flow (owner → friend → approve → unlock)
3. Timer failsafe + multiple friends support + basic UI polish
4. Canvas integration + shame post mechanic + WidgetKit countdown + TestFlight beta