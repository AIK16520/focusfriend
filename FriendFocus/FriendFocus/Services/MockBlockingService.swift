// MockBlockingService.swift
// Phase 2 blocking layer.
//
// BLOCKING_ENABLED = false  → fires local notifications + print logs (Simulator-safe)
// BLOCKING_ENABLED = true   → delegates to real BlockingManager (requires FamilyControls
//                             entitlement + physical device + $99 Apple dev account)
//
// Flip the flag when all three prerequisites are met. No other code changes required.

import Foundation

private let BLOCKING_ENABLED = false

@MainActor
final class MockBlockingService {
    static let shared = MockBlockingService()
    private init() {}

    // MARK: – Called by SessionViewModel when session starts

    func applyBlock(appCount: Int) {
        if BLOCKING_ENABLED {
            BlockingManager.shared.startSession()
        } else {
            print("FriendFocus [mock] ▶ BLOCK APPLIED — \(appCount) app(s) would be blocked")
            NotificationService.shared.fire(
                title: "🔒 Block Applied (mock)",
                body: "\(appCount) app\(appCount == 1 ? "" : "s") are now blocked.",
                identifier: "block.applied"
            )
        }
        SharedStore.isSessionActive = true
    }

    // MARK: – Called when friend approves or owner cancels

    func liftBlock(by name: String) {
        if BLOCKING_ENABLED {
            BlockingManager.shared.stopSession()
        } else {
            print("FriendFocus [mock] ▶ BLOCK LIFTED — unlocked by \(name)")
            NotificationService.shared.fire(
                title: "🔓 Block Lifted (mock)",
                body: "\(name) approved your unlock.",
                identifier: "block.lifted"
            )
        }
        SharedStore.isSessionActive = false
        SharedStore.activeSessionID = nil
    }

    // MARK: – Called when friend denies (block stays applied)

    func notifyDenied(by name: String) {
        print("FriendFocus [mock] ▶ UNLOCK DENIED by \(name) — block remains")
        NotificationService.shared.fire(
            title: "❌ Unlock Denied (mock)",
            body: "\(name) said stay focused. Block remains.",
            identifier: "block.denied"
        )
        // Block intentionally NOT lifted — SharedStore.isSessionActive stays true
    }
}
