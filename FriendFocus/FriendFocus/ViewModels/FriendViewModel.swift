import Foundation

@MainActor
final class FriendViewModel: ObservableObject {
    @Published var friends: [AppUser] = []
    @Published var isLoading = false
    @Published var error: String?

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

    /// Returns true on success, false + sets error on failure.
    func addFriend(myUID: String, code: String) async -> Bool {
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
            try await FirestoreService.shared.addFriend(myUID: myUID, theirUID: found.id ?? "")
            friends.append(found)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
