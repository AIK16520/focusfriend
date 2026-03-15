// FirestoreService.swift
// All Firestore reads, writes, and real-time listeners.
//
// Firestore structure:
//   users/{uid}           → AppUser
//   lockSessions/{id}     → LockSession
//
// Note: listenForIncomingSessions filters by friendUID only and sieves status
// client-side to avoid requiring a composite index during development.

import Foundation
import FirebaseFirestore

final class FirestoreService {
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

    /// Mutually adds both users as friends in one atomic batch.
    func addFriend(myUID: String, theirUID: String) async throws {
        let batch = db.batch()
        batch.updateData(
            ["friends": FieldValue.arrayUnion([theirUID])],
            forDocument: db.collection("users").document(myUID)
        )
        batch.updateData(
            ["friends": FieldValue.arrayUnion([myUID])],
            forDocument: db.collection("users").document(theirUID)
        )
        try await batch.commit()
    }

    /// Fetches multiple users by UID. Firestore `in` queries are capped at 10; this chunks automatically.
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

    // MARK: – Sessions

    func createSession(_ session: LockSession) async throws -> String {
        let ref = db.collection("lockSessions").document()   // auto-ID
        try ref.setData(from: session)
        return ref.documentID
    }

    func approveSession(_ id: String) async throws {
        try await db.collection("lockSessions").document(id).updateData([
            "status": LockSession.Status.approved.rawValue,
            "updatedAt": Timestamp(date: Date()),
            "resolvedAt": Timestamp(date: Date())
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

    func completeSession(_ id: String) async throws {
        try await db.collection("lockSessions").document(id).updateData([
            "status": LockSession.Status.complete.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
    }

    /// Owner listens to a single session doc for status changes.
    func listenToSession(_ id: String, onChange: @escaping (LockSession?) -> Void) -> ListenerRegistration {
        db.collection("lockSessions").document(id).addSnapshotListener { snap, _ in
            onChange(try? snap?.data(as: LockSession.self))
        }
    }

    /// Friend listens for sessions where they are the designated friend.
    /// Filters client-side for .pending status to avoid needing a composite Firestore index.
    func listenForIncomingSessions(
        friendUID: String,
        onChange: @escaping ([LockSession]) -> Void
    ) -> ListenerRegistration {
        db.collection("lockSessions")
            .whereField("friendUID", isEqualTo: friendUID)
            .addSnapshotListener { snap, _ in
                let all = snap?.documents.compactMap { try? $0.data(as: LockSession.self) } ?? []
                onChange(all.filter { $0.status == .pending })
            }
    }
}
