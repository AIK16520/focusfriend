---
name: FocusFriend Phase 1 Implementation
description: iOS app blocking app — Phase 1 complete (FamilyControls + DeviceActivityMonitor extension)
type: project
---

Phase 1 of FocusFriend iOS app blocking is implemented.

**Bundle IDs:** main app `LH.FriendFocus`, extension `LH.FriendFocus.FocusMonitor`, App Group `group.LH.FriendFocus.shared`

**Xcode project:** `/Users/alikhokhar/Desktop/focusfriend/FriendFocus/FriendFocus.xcodeproj`

**Key files:**
- `FriendFocus/SharedStore.swift` — App Group UserDefaults bridge (shared by both targets)
- `FriendFocus/BlockingManager.swift` — auth, FamilyActivityPicker, ManagedSettings, DeviceActivity
- `FriendFocus/ContentView.swift` — minimal UI: authorize → pick apps → start/stop session
- `FriendFocus/FriendFocus.entitlements` — FamilyControls + App Group (main app)
- `FocusMonitor/FocusMonitorExtension.swift` — DeviceActivityMonitor subclass (enforces shields when app is killed)
- `FocusMonitor/Info.plist` — NSExtensionPointIdentifier: `com.apple.deviceactivity.monitor`
- `FocusMonitor/FocusMonitor.entitlements` — FamilyControls + App Group (extension)

**Next phases (not yet built):** friend unlock flow, backend, timer unlock.

**Why:** FamilyControls entitlement must be Apple-approved for production; physical device required for testing.

**How to apply:** When continuing work on this project, the extension target is `FocusMonitor` and the App Group ID is `group.LH.FriendFocus.shared`.
