import Foundation
import FirebaseFirestore

enum AppError: LocalizedError {
    case alreadyFriends
    case requestAlreadySent

    var errorDescription: String? {
        switch self {
        case .alreadyFriends: return "You're already friends."
        case .requestAlreadySent: return "Friend request already sent."
        }
    }
}

final class FirestoreService: FirestoreServiceProtocol {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private init() {}

    // MARK: – Users

    func createUser(uid: String, user: AppUser) async throws {
        try db.collection("users").document(uid).setData(from: user, merge: true)
    }

    func getUser(uid: String) async throws -> AppUser? {
        let snap = try await db.collection("users").document(uid).getDocument()
        return try? snap.data(as: AppUser.self)
    }

    func getUserByInviteCode(_ code: String) async throws -> AppUser? {
        let snap = try await db.collection("users")
            .whereField("inviteCode", isEqualTo: code.uppercased())
            .limit(to: 1)
            .getDocuments()
        return try? snap.documents.first?.data(as: AppUser.self)
    }

    func updateFCMToken(_ token: String, forUID uid: String) async throws {
        try await db.collection("users").document(uid).updateData(["fcmToken": token])
    }

    func addFriendDirect(myUID: String, theirUID: String) async throws {
        let batch = db.batch()
        batch.updateData(["friends": FieldValue.arrayUnion([theirUID])], forDocument: db.collection("users").document(myUID))
        batch.updateData(["friends": FieldValue.arrayUnion([myUID])], forDocument: db.collection("users").document(theirUID))
        try await batch.commit()
    }

    func fetchUsers(uids: [String]) async throws -> [AppUser] {
        guard !uids.isEmpty else { return [] }
        let chunks = stride(from: 0, to: uids.count, by: 10)
            .map { Array(uids[$0 ..< min($0 + 10, uids.count)]) }
        var results: [AppUser] = []
        for chunk in chunks {
            let snap = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            results += snap.documents.compactMap { try? $0.data(as: AppUser.self) }
        }
        return results
    }

    // MARK: – Friend Requests

    func sendFriendRequest(from fromUID: String, fromName: String, to toUID: String, toName: String) async throws {
        let myDoc = try await db.collection("users").document(fromUID).getDocument()
        if let friends = myDoc.data()?["friends"] as? [String], friends.contains(toUID) {
            throw AppError.alreadyFriends
        }
        let existing = try await db.collection("friendRequests")
            .whereField("fromUID", isEqualTo: fromUID)
            .whereField("toUID", isEqualTo: toUID)
            .whereField("status", isEqualTo: FriendRequest.Status.pending.rawValue)
            .getDocuments()
        if !existing.documents.isEmpty { throw AppError.requestAlreadySent }

        let request = FriendRequest(fromUID: fromUID, fromName: fromName, toUID: toUID, toName: toName, status: .pending, createdAt: Date())
        try db.collection("friendRequests").document().setData(from: request)
    }

    func acceptFriendRequest(_ requestID: String, fromUID: String, toUID: String) async throws {
        let batch = db.batch()
        batch.updateData(["status": FriendRequest.Status.accepted.rawValue], forDocument: db.collection("friendRequests").document(requestID))
        batch.updateData(["friends": FieldValue.arrayUnion([toUID])], forDocument: db.collection("users").document(fromUID))
        batch.updateData(["friends": FieldValue.arrayUnion([fromUID])], forDocument: db.collection("users").document(toUID))
        try await batch.commit()
    }

    func declineFriendRequest(_ requestID: String) async throws {
        try await db.collection("friendRequests").document(requestID).updateData(["status": FriendRequest.Status.declined.rawValue])
    }

    func listenForFriendRequests(uid: String, onChange: @escaping ([FriendRequest]) -> Void) -> ListenerRegistration {
        db.collection("friendRequests")
            .whereField("toUID", isEqualTo: uid)
            .whereField("status", isEqualTo: FriendRequest.Status.pending.rawValue)
            .addSnapshotListener { snap, _ in
                let requests = snap?.documents.compactMap { try? $0.data(as: FriendRequest.self) } ?? []
                onChange(requests)
            }
    }

    // MARK: – Sessions

    func createSession(_ session: LockSession) async throws -> String {
        let ref = db.collection("lockSessions").document()
        try ref.setData(from: session)
        return ref.documentID
    }

    func requestUnlock(_ id: String) async throws {
        try await db.collection("lockSessions").document(id).updateData([
            "status": LockSession.Status.unlockRequested.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    func approveSession(_ id: String, byUID: String, byName: String) async throws {
        try await db.collection("lockSessions").document(id).updateData([
            "status": LockSession.Status.approved.rawValue,
            "updatedAt": Timestamp(date: Date()),
            "resolvedAt": Timestamp(date: Date()),
            "approvedByUID": byUID,
            "approvedByName": byName
        ])
    }

    func denySession(_ id: String) async throws {
        try await db.collection("lockSessions").document(id).updateData([
            "status": LockSession.Status.denied.rawValue,
            "updatedAt": Timestamp(date: Date()),
            "resolvedAt": Timestamp(date: Date())
        ])
    }

    func cancelSession(_ id: String) async throws {
        try await db.collection("lockSessions").document(id).updateData([
            "status": LockSession.Status.cancelled.rawValue,
            "updatedAt": Timestamp(date: Date()),
            "resolvedAt": Timestamp(date: Date())
        ])
    }

    func expireSession(_ id: String) async throws {
        try await db.collection("lockSessions").document(id).updateData([
            "status": LockSession.Status.timerExpired.rawValue,
            "updatedAt": Timestamp(date: Date()),
            "resolvedAt": Timestamp(date: Date())
        ])
    }

    func completeSession(_ id: String) async throws {
        try await db.collection("lockSessions").document(id).updateData([
            "status": LockSession.Status.complete.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    func listenToSession(_ id: String, onChange: @escaping (LockSession?) -> Void) -> ListenerRegistration {
        db.collection("lockSessions").document(id).addSnapshotListener { snap, _ in
            onChange(try? snap?.data(as: LockSession.self))
        }
    }

    func listenForIncomingSessions(friendUID: String, onChange: @escaping ([LockSession]) -> Void) -> ListenerRegistration {
        db.collection("lockSessions")
            .whereField("friendUIDs", arrayContains: friendUID)
            .addSnapshotListener { snap, _ in
                let all = snap?.documents.compactMap { try? $0.data(as: LockSession.self) } ?? []
                onChange(all.filter { $0.status == .pending || $0.status == .unlockRequested })
            }
    }
}
