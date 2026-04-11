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
    private var timerTask: Task<Void, Never>?

    private let service: FirestoreServiceProtocol

    init(service: FirestoreServiceProtocol = FirestoreService.shared) {
        self.service = service
    }

    deinit {
        ownerListener?.remove()
        friendListener?.remove()
        timerTask?.cancel()
    }

    // MARK: – Friend listener

    func startFriendListener(uid: String) {
        guard friendListeningUID != uid else { return }
        friendListeningUID = uid
        friendListener?.remove()
        friendListener = service.listenForIncomingSessions(friendUID: uid) { [weak self] sessions in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let existing = Set(self.incomingRequests.compactMap(\.id))
                self.incomingRequests = sessions
                for session in sessions where !existing.contains(session.id ?? "") {
                    switch session.status {
                    case .pending:
                        NotificationService.shared.fire(
                            title: "\(session.ownerName) is now locked 🔒",
                            body: "They'll notify you when they want to unlock.",
                            identifier: "incoming.locked.\(session.id ?? UUID().uuidString)"
                        )
                    case .unlockRequested:
                        NotificationService.shared.fire(
                            title: "\(session.ownerName) wants to unlock 🔓",
                            body: "Tap to approve or deny their unlock request.",
                            identifier: "incoming.unlock.\(session.id ?? UUID().uuidString)"
                        )
                    default:
                        break
                    }
                }
                if sessions.contains(where: { $0.status == .unlockRequested }) {
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

    func startSession(owner: AppUser, friends: [AppUser], maxDurationSeconds: TimeInterval? = nil) async {
        guard let ownerUID = owner.id, !friends.isEmpty else { return }
        isStartingSession = true
        defer { isStartingSession = false }

        let appCount = BlockingManager.shared.selection.applicationTokens.count
        let friendUIDs = friends.compactMap(\.id)
        let friendNames = friends.map(\.displayName)
        let expiresAt = maxDurationSeconds.map { Date().addingTimeInterval($0) }

        let session = LockSession(
            ownerUID: ownerUID,
            ownerName: owner.displayName,
            friendUIDs: friendUIDs,
            friendNames: friendNames,
            status: .pending,
            appTokensCount: appCount,
            createdAt: Date(),
            updatedAt: Date(),
            expiresAt: expiresAt
        )

        do {
            let sessionID = try await service.createSession(session)
            SharedStore.activeSessionID = sessionID
            SharedStore.sessionExpiresAt = expiresAt
            MockBlockingService.shared.applyBlock(appCount: appCount)
            if let expiresAt {
                startTimer(expiresAt: expiresAt, sessionID: sessionID)
            }
            startOwnerListener(sessionID: sessionID)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: – Owner: request unlock

    func requestUnlock() async {
        guard let sessionID = SharedStore.activeSessionID else { return }
        do { try await service.requestUnlock(sessionID) }
        catch { self.error = error.localizedDescription }
    }

    // MARK: – Owner: cancel

    func cancelSession() async {
        timerTask?.cancel()
        timerTask = nil
        guard let sessionID = SharedStore.activeSessionID else {
            MockBlockingService.shared.liftBlock(by: "you")
            activeSession = nil
            return
        }
        do { try await service.cancelSession(sessionID) }
        catch { self.error = error.localizedDescription }
    }

    // MARK: – Friend: approve / deny

    func approve(session: LockSession, byUID: String, byName: String) async {
        guard let id = session.id else { return }
        do { try await service.approveSession(id, byUID: byUID, byName: byName) }
        catch { self.error = error.localizedDescription }
    }

    func deny(session: LockSession) async {
        guard let id = session.id else { return }
        do { try await service.denySession(id) }
        catch { self.error = error.localizedDescription }
    }

    // MARK: – Dismiss

    func dismissActiveSession() {
        timerTask?.cancel()
        timerTask = nil
        ownerListener?.remove()
        ownerListener = nil
        activeSession = nil
        SharedStore.activeSessionID = nil
        SharedStore.sessionExpiresAt = nil
    }

    // MARK: – Timer

    private func startTimer(expiresAt: Date, sessionID: String) {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            let delay = expiresAt.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await self?.autoExpire(sessionID: sessionID)
        }
    }

    private func autoExpire(sessionID: String) async {
        do {
            try await service.expireSession(sessionID)
            MockBlockingService.shared.liftBlock(by: "timer")
            NotificationService.shared.fire(
                title: "Lock Expired ⏰",
                body: "Your maximum lock duration was reached. You're unlocked.",
                identifier: "session.expired"
            )
        } catch {
            self.error = error.localizedDescription
        }
        timerTask = nil
        SharedStore.sessionExpiresAt = nil
    }

    // MARK: – Private owner listener

    private func startOwnerListener(sessionID: String) {
        ownerListener?.remove()
        ownerListener = service.listenToSession(sessionID) { [weak self] session in
            Task { @MainActor [weak self] in
                guard let self, let session else { return }
                self.activeSession = session

                switch session.status {
                case .approved:
                    self.timerTask?.cancel()
                    MockBlockingService.shared.liftBlock(by: session.approvedByName ?? session.primaryFriendName)
                    try? await self.service.completeSession(sessionID)

                case .denied:
                    MockBlockingService.shared.notifyDenied(by: session.primaryFriendName)

                case .cancelled:
                    self.timerTask?.cancel()
                    MockBlockingService.shared.liftBlock(by: "you")

                case .timerExpired:
                    self.timerTask?.cancel()
                    MockBlockingService.shared.liftBlock(by: "timer")
                    try? await self.service.completeSession(sessionID)

                case .pending, .unlockRequested, .complete:
                    break
                }
            }
        }
    }
}
