// AuthService.swift
// Uses Firebase anonymous auth — no Apple Sign In, no email/password.
// Works without the $99 developer account and runs in Simulator.
// A stable UID is persisted by the Firebase SDK in Keychain across app launches.

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isSignedIn = false
    @Published var currentUser: AppUser?

    var uid: String? { Auth.auth().currentUser?.uid }

    private var authListener: AuthStateDidChangeListenerHandle?

    private init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.isSignedIn = user != nil
                if let uid = user?.uid {
                    self?.currentUser = try? await FirestoreService.shared.getUser(uid: uid)
                } else {
                    self?.currentUser = nil
                }
            }
        }
    }

    func signIn(displayName: String) async throws {
        let result = try await Auth.auth().signInAnonymously()
        let uid = result.user.uid

        if let existing = try? await FirestoreService.shared.getUser(uid: uid) {
            currentUser = existing
        } else {
            let code = Self.generateInviteCode()
            let user = AppUser(displayName: displayName, inviteCode: code)
            try await FirestoreService.shared.createUser(uid: uid, user: user)
            currentUser = user
        }
        SharedStore.currentUserID = uid
        isSignedIn = true
    }

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
        SharedStore.currentUserID = nil
        isSignedIn = false
    }

    // Omit confusable chars (O, 0, I, 1)
    private static func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
