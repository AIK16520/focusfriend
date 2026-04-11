import Foundation
import FirebaseFirestore

@MainActor
final class FriendViewModel: ObservableObject {
    @Published var friends: [AppUser] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var isLoading = false
    @Published var error: String?

    private var requestListener: ListenerRegistration?
    private let service: FirestoreServiceProtocol

    init(service: FirestoreServiceProtocol = FirestoreService.shared) {
        self.service = service
    }

    func startRequestListener(uid: String) {
        requestListener?.remove()
        requestListener = service.listenForFriendRequests(uid: uid) { [weak self] requests in
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
            friends = try await service.fetchUsers(uids: uids)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func sendRequest(myUID: String, myName: String, code: String) async -> Bool {
        guard code.count == 6 else { error = "Code must be 6 characters."; return false }
        isLoading = true
        defer { isLoading = false }
        error = nil
        do {
            guard let found = try await service.getUserByInviteCode(code) else {
                error = "No user found with that code."
                return false
            }
            guard found.id != myUID else {
                error = "That's your own invite code."
                return false
            }
            try await service.sendFriendRequest(from: myUID, fromName: myName, to: found.id ?? "", toName: found.displayName)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func accept(request: FriendRequest) async {
        guard let id = request.id else { return }
        do {
            try await service.acceptFriendRequest(id, fromUID: request.fromUID, toUID: request.toUID)
            incomingRequests.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func decline(request: FriendRequest) async {
        guard let id = request.id else { return }
        do {
            try await service.declineFriendRequest(id)
            incomingRequests.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
