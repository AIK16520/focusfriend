import Foundation
import FirebaseFirestore

protocol FirestoreServiceProtocol {
    func createUser(uid: String, user: AppUser) async throws
    func getUser(uid: String) async throws -> AppUser?
    func getUserByInviteCode(_ code: String) async throws -> AppUser?
    func addFriendDirect(myUID: String, theirUID: String) async throws
    func fetchUsers(uids: [String]) async throws -> [AppUser]
    func sendFriendRequest(from fromUID: String, fromName: String, to toUID: String, toName: String) async throws
    func acceptFriendRequest(_ requestID: String, fromUID: String, toUID: String) async throws
    func declineFriendRequest(_ requestID: String) async throws
    func listenForFriendRequests(uid: String, onChange: @escaping ([FriendRequest]) -> Void) -> ListenerRegistration
    func updateFCMToken(_ token: String, forUID uid: String) async throws
    func createSession(_ session: LockSession) async throws -> String
    func requestUnlock(_ id: String) async throws
    func approveSession(_ id: String, byUID: String, byName: String) async throws
    func denySession(_ id: String) async throws
    func cancelSession(_ id: String) async throws
    func expireSession(_ id: String) async throws
    func completeSession(_ id: String) async throws
    func listenToSession(_ id: String, onChange: @escaping (LockSession?) -> Void) -> ListenerRegistration
    func listenForIncomingSessions(friendUID: String, onChange: @escaping ([LockSession]) -> Void) -> ListenerRegistration
}
