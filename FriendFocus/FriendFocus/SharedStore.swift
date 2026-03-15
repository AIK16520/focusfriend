// SharedStore.swift
// App Group UserDefaults bridge shared between the main app and FocusMonitor extension.
// Keep in sync with FocusMonitor/SharedStore.swift.

import Foundation
import FamilyControls

let kAppGroupID = "group.LH.FriendFocus.shared"

enum SharedStore {
    static var defaults: UserDefaults {
        UserDefaults(suiteName: kAppGroupID) ?? .standard
    }

    // MARK: – Phase 1: blocking state (read by FocusMonitor extension)

    static var isSessionActive: Bool {
        get { defaults.bool(forKey: "sessionActive") }
        set { defaults.set(newValue, forKey: "sessionActive"); defaults.synchronize() }
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: "selectedApps")
        defaults.synchronize()
    }

    static func loadSelection() -> FamilyActivitySelection? {
        guard let data = defaults.data(forKey: "selectedApps") else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    // MARK: – Phase 2: identity & session correlation

    /// The current user's Firebase UID — written at sign-in, cleared at sign-out.
    static var currentUserID: String? {
        get { defaults.string(forKey: "currentUserID") }
        set { defaults.set(newValue, forKey: "currentUserID"); defaults.synchronize() }
    }

    /// The Firestore document ID of the active lock session.
    /// Written when a session starts, cleared when it resolves.
    static var activeSessionID: String? {
        get { defaults.string(forKey: "activeSessionID") }
        set { defaults.set(newValue, forKey: "activeSessionID"); defaults.synchronize() }
    }
}
