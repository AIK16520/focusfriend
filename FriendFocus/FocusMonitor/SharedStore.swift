// SharedStore.swift (FocusMonitor copy)
// Duplicated here because each target only sees its own file-system synchronized group.
// Keep in sync with FriendFocus/SharedStore.swift.

import Foundation
import FamilyControls

let kAppGroupID = "group.LH.FriendFocus.shared"

enum SharedStore {
    static var defaults: UserDefaults {
        UserDefaults(suiteName: kAppGroupID) ?? .standard
    }

    static var isSessionActive: Bool {
        get { defaults.bool(forKey: "sessionActive") }
        set {
            defaults.set(newValue, forKey: "sessionActive")
            defaults.synchronize()
        }
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

    static var currentUserID: String? {
        get { defaults.string(forKey: "currentUserID") }
        set { defaults.set(newValue, forKey: "currentUserID"); defaults.synchronize() }
    }

    static var activeSessionID: String? {
        get { defaults.string(forKey: "activeSessionID") }
        set { defaults.set(newValue, forKey: "activeSessionID"); defaults.synchronize() }
    }
}
