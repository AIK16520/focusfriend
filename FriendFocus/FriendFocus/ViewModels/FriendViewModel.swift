import Foundation
import FirebaseFirestore

@MainActor
final class FriendViewModel: ObservableObject {
    @Published var friends: [AppUser] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var isLoading = false
    @Published var error: String?

    private var requestListener: ListenerRegistration?

    func startRequestListener(uid: String) {
        requestListener?.remove()
        requestListener = FirestoreService.shared.listenForFriendRequests(uid: uid) { [weak self] requests in
            Task { @MainActor [weak self] in
                self?.incomingRequests = requests
            }
        }
    }

    func stopRequestListener() {
        requestListener?.remove()
        requestListener = nil
    }

    func fetchFriends(uids: [String]) async {
        guard !uids.isEmpty else { friends = []; return }
        isLoading = true
        defer { isLoading = false }
        do {
            friends = try await FirestoreService.shared.fetchUsers(uids: uids)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Sends a friend request using their invite code. Returns true on success.
    func sendRequest(myUID: String, myName: String, code: String) async -> Bool {
        guard code.count == 6 else { error = "Code must be 6 characters."; return false }
        isLoading = true
        defer { isLoading = false }
        error = nil
        do {
            guard let found = try await FirestoreService.shared.getUserByInviteCode(code) else {
                error = "No user found with that code."
                return false
            }
            guard found.id != myUID else {
                error = "That's your own invite code."
                return false
            }
            try await FirestoreService.shared.sendFriendRequest(
                from: myUID, fromName: myName,
                to: found.id ?? "", toName: found.displayName
            )
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func accept(request: FriendRequest) async {
        guard let id = request.id else { return }
        do {
            try await FirestoreService.shared.acceptFriendRequest(id, fromUID: request.fromUID, toUID: request.toUID)
            incomingRequests.removeAll { $0.id == id }
            // friends list refresh is handled by AuthService's Firestore listener + onReceive in MainTabView
        } catch {
            self.error = error.localizedDescription
        }
    }

    func decline(request: FriendRequest) async {
        guard let id = request.id else { return }
        do {
            try await FirestoreService.shared.declineFriendRequest(id)
            incomingRequests.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
