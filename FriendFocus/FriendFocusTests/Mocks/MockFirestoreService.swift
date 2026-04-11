import Foundation
import FirebaseFirestore
@testable import FriendFocus

final class MockFirestoreService: FirestoreServiceProtocol {
    // MARK: - Stored state
    var users: [String: AppUser] = [:]
    var sessions: [String: LockSession] = [:]
    var friendRequests: [String: FriendRequest] = [:]

    // MARK: - Call tracking
    var createSessionCalled = false
    var approveSessionCalled = false
    var denySessionCalled = false
    var cancelSessionCalled = false
    var expireSessionCalled = false
    var completeSessionCalled = false
    var requestUnlockCalled = false
    var updateFCMTokenCalled = false
    var lastFCMToken: String?

    // MARK: - Errors to throw
    var errorToThrow: Error?

    // MARK: - Users

    func createUser(uid: String, user: AppUser) async throws {
        if let e = errorToThrow { throw e }
        users[uid] = user
    }

    func getUser(uid: String) async throws -> AppUser? {
        if let e = errorToThrow { throw e }
        return users[uid]
    }

    func getUserByInviteCode(_ code: String) async throws -> AppUser? {
        if let e = errorToThrow { throw e }
        return users.values.first { $0.inviteCode == code }
    }

    func updateFCMToken(_ token: String, forUID uid: String) async throws {
        if let e = errorToThrow { throw e }
        updateFCMTokenCalled = true
        lastFCMToken = token
        users[uid]?.fcmToken = token
    }

    func addFriendDirect(myUID: String, theirUID: String) async throws {
        if let e = errorToThrow { throw e }
    }

    func fetchUsers(uids: [String]) async throws -> [AppUser] {
        if let e = errorToThrow { throw e }
        return uids.compactMap { users[$0] }
    }

    // MARK: - Friend Requests

    func sendFriendRequest(from fromUID: String, fromName: String, to toUID: String, toName: String) async throws {
        if let e = errorToThrow { throw e }
        let id = UUID().uuidString
        friendRequests[id] = FriendRequest(id: id, fromUID: fromUID, fromName: fromName, toUID: toUID, toName: toName, status: .pending, createdAt: Date())
    }

    func acceptFriendRequest(_ requestID: String, fromUID: String, toUID: String) async throws {
        if let e = errorToThrow { throw e }
        friendRequests[requestID]?.status = .accepted
    }

    func declineFriendRequest(_ requestID: String) async throws {
        if let e = errorToThrow { throw e }
        friendRequests[requestID]?.status = .declined
    }

    func listenForFriendRequests(uid: String, onChange: @escaping ([FriendRequest]) -> Void) -> ListenerRegistration {
        onChange([])
        return MockListenerRegistration()
    }

    // MARK: - Sessions

    func createSession(_ session: LockSession) async throws -> String {
        if let e = errorToThrow { throw e }
        createSessionCalled = true
        let id = UUID().uuidString
        sessions[id] = session
        return id
    }

    func requestUnlock(_ id: String) async throws {
        if let e = errorToThrow { throw e }
        requestUnlockCalled = true
        sessions[id]?.status = .unlockRequested
    }

    func approveSession(_ id: String, byUID: String, byName: String) async throws {
        if let e = errorToThrow { throw e }
        approveSessionCalled = true
        sessions[id]?.status = .approved
        sessions[id]?.approvedByName = byName
    }

    func denySession(_ id: String) async throws {
        if let e = errorToThrow { throw e }
        denySessionCalled = true
        sessions[id]?.status = .denied
    }

    func cancelSession(_ id: String) async throws {
        if let e = errorToThrow { throw e }
        cancelSessionCalled = true
        sessions[id]?.status = .cancelled
    }

    func expireSession(_ id: String) async throws {
        if let e = errorToThrow { throw e }
        expireSessionCalled = true
        sessions[id]?.status = .timerExpired
    }

    func completeSession(_ id: String) async throws {
        if let e = errorToThrow { throw e }
        completeSessionCalled = true
        sessions[id]?.status = .complete
    }

    func listenToSession(_ id: String, onChange: @escaping (LockSession?) -> Void) -> ListenerRegistration {
        onChange(sessions[id])
        return MockListenerRegistration()
    }

    func listenForIncomingSessions(friendUID: String, onChange: @escaping ([LockSession]) -> Void) -> ListenerRegistration {
        let matching = sessions.values.filter { $0.friendUIDs.contains(friendUID) && ($0.status == .pending || $0.status == .unlockRequested) }
        onChange(Array(matching))
        return MockListenerRegistration()
    }
}

final class MockListenerRegistration: NSObject, ListenerRegistration {
    func remove() {}
}
