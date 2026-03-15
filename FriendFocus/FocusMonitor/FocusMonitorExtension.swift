// FocusMonitorExtension.swift
// DeviceActivityMonitor extension — enforces app shields independently of the main app process.

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

final class FocusMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    // Called when the DeviceActivity schedule interval begins (including immediately on
    // startMonitoring if the current time is already within the scheduled interval).
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        applyShieldIfNeeded()
    }

    // Called when the schedule interval ends. Clear the shield only if the session
    // was already stopped by the main app (SharedStore.isSessionActive == false).
    // If the session is still active, the next intervalDidStart re-applies it.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if !SharedStore.isSessionActive {
            store.shield.applications = nil
        }
    }

    // MARK: – Helpers

    private func applyShieldIfNeeded() {
        guard SharedStore.isSessionActive,
              let selection = SharedStore.loadSelection(),
              !selection.applicationTokens.isEmpty else {
            store.shield.applications = nil
            return
        }
        store.shield.applications = selection.applicationTokens
    }
}
