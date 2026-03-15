// SessionViewModel.swift
// Owns all session lifecycle logic for both the owner and friend sides.
// Lives at the MainTabView level so listeners persist across tab switches.

import Foundation
import FirebaseFirestore

@MainActor
final class SessionViewModel: ObservableObject {

    // MARK: – Owner side

    @Published var activeSession: LockSession?
    @Published var isStartingSession = false

    // MARK: – Friend side

    @Published var incomingRequests: [LockSession] = []
    @Published var showingIncomingRequests = false

    // MARK: – Shared

    @Published var error: String?

    // MARK: – Private

    private var ownerListener: ListenerRegistration?
    private var friendListener: ListenerRegistration?
    private var friendListeningUID: String?

    deinit {
        ownerListener?.remove()
        friendListener?.remove()
    }

    // MARK: – Friend listener (start once at MainTabView level)

    func startFriendListener(uid: String) {
        guard friendListeningUID != uid else { return }
        friendListeningUID = uid
        friendListener?.remove()
        friendListener = FirestoreService.shared.listenForIncomingSessions(friendUID: uid) { [weak self] sessions in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let existing = Set(self.incomingRequests.compactMap(\.id))
                self.incomingRequests = sessions
                // Fire a local notification for each newly arrived request
                for session in sessions where !existing.contains(session.id ?? "") {
                    NotificationService.shared.fire(
                        title: "\(session.ownerName) wants to unlock",
                        body: "Tap to approve or deny their unlock request.",
                        identifier: "incoming.\(session.id ?? UUID().uuidString)"
                    )
                }
                if !sessions.isEmpty {
                    self.showingIncomingRequests = true
                }
            }
        }
    }

    func stopFriendListener() {
        friendListener?.remove()
        friendListener = nil
        friendListeningUID = nil
    }

    // MARK: – Owner: start session

    func startSession(owner: AppUser, friend: AppUser) async {
        guard let ownerUID = owner.id else { return }
        isStartingSession = true
        defer { isStartingSession = false }

        let appCount = BlockingManager.shared.selection.applicationTokens.count

        let session = LockSession(
            ownerUID: ownerUID,
            ownerName: owner.displayName,
            friendUID: friend.id ?? "",
            friendName: friend.displayName,
            status: .pending,
            appTokensCount: appCount,
            createdAt: Date(),
            updatedAt: Date()
        )

        do {
            let sessionID = try await FirestoreService.shared.createSession(session)
            SharedStore.activeSessionID = sessionID

            // Apply the block (mock or real depending on BLOCKING_ENABLED)
            MockBlockingService.shared.applyBlock(appCount: appCount)

            startOwnerListener(sessionID: sessionID)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: – Owner: emergency stop

    func cancelSession() async {
        guard let sessionID = SharedStore.activeSessionID else {
            // No Firestore record yet (shouldn't happen), just clean up locally
            MockBlockingService.shared.liftBlock(by: "you")
            activeSession = nil
            return
        }
        do {
            try await FirestoreService.shared.cancelSession(sessionID)
            // Listener will fire and handle liftBlock
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: – Friend: approve / deny

    func approve(session: LockSession) async {
        guard let id = session.id else { return }
        do { try await FirestoreService.shared.approveSession(id) }
        catch { self.error = error.localizedDescription }
    }

    func deny(session: LockSession) async {
        guard let id = session.id else { return }
        do { try await FirestoreService.shared.denySession(id) }
        catch { self.error = error.localizedDescription }
    }

    // MARK: – Dismiss resolved session from UI

    func dismissActiveSession() {
        ownerListener?.remove()
        ownerListener = nil
        activeSession = nil
    }

    // MARK: – Private

    private func startOwnerListener(sessionID: String) {
        ownerListener?.remove()
        ownerListener = FirestoreService.shared.listenToSession(sessionID) { [weak self] session in
            Task { @MainActor [weak self] in
                guard let self, let session else { return }
                self.activeSession = session

                switch session.status {
                case .approved:
                    MockBlockingService.shared.liftBlock(by: session.friendName)
                    try? await FirestoreService.shared.completeSession(sessionID)

                case .denied:
                    MockBlockingService.shared.notifyDenied(by: session.friendName)
                    // Block intentionally stays — owner must use cancelSession() to force-stop

                case .cancelled:
                    MockBlockingService.shared.liftBlock(by: "you")

                case .pending, .complete:
                    break
                }
            }
        }
    }
}
