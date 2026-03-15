// BlockingManager.swift
// Owns all FamilyControls / ManagedSettings / DeviceActivity logic for the main app.
//
// Required capabilities (both targets):
//   • FamilyControls  (entitlement must be approved by Apple for real devices)
//   • App Groups      → group.LH.FriendFocus.shared
//
// Testing: must run on a physical device; FamilyControls doesn't work in Simulator.

import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import Combine

@MainActor
final class BlockingManager: ObservableObject {

    static let shared = BlockingManager()

    // MARK: – Published state

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var isSessionActive = false
    @Published var selection = FamilyActivitySelection()
    @Published var showingPicker = false

    // MARK: – Private

    private let store = ManagedSettingsStore()
    private let activityCenter = DeviceActivityCenter()

    // Stable name for the DeviceActivity schedule.
    private static let sessionActivity = DeviceActivityName("com.lh.friendfocus.session")

    // MARK: – Init

    private init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        isSessionActive = SharedStore.isSessionActive
        if let saved = SharedStore.loadSelection() {
            selection = saved
        }
    }

    // MARK: – Authorization

    /// Call once from onboarding. Presents the system Screen Time consent sheet.
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            print("FriendFocus: authorization error: \(error)")
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: – Session management

    /// Start blocking the selected apps.
    /// The ManagedSettings shield persists at the OS level even after this process is killed.
    /// The DeviceActivity schedule wakes the extension so it can re-own the shield.
    func startSession() {
        let tokens = selection.applicationTokens
        guard !tokens.isEmpty else { return }

        // Persist state so the extension can read it.
        SharedStore.isSessionActive = true
        SharedStore.saveSelection(selection)
        isSessionActive = true

        // Apply the shield immediately — it is OS-enforced and survives process death.
        store.shield.applications = tokens

        // Start a full-day repeating DeviceActivity schedule.
        // intervalDidStart fires immediately if the current time is within the interval,
        // allowing FocusMonitorExtension to take ownership of the shield.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        do {
            try activityCenter.startMonitoring(Self.sessionActivity, during: schedule)
        } catch {
            print("FriendFocus: startMonitoring error: \(error)")
        }
    }

    /// Stop blocking. Clears the shield and stops the DeviceActivity schedule.
    func stopSession() {
        SharedStore.isSessionActive = false
        isSessionActive = false

        // Removing the shield from the main app works immediately.
        // The extension will also clear its shield when intervalDidEnd fires
        // or when it next evaluates SharedStore.isSessionActive == false.
        store.shield.applications = nil
        activityCenter.stopMonitoring([Self.sessionActivity])
    }
}
