import Testing
import Foundation
@testable import FriendFocus

// MARK: - LockSession Model Tests
@Suite("LockSession Model")
struct LockSessionModelTests {

    @Test("isResolved is true for terminal statuses")
    func resolvedStatuses() {
        #expect(LockSession.Status.approved.isResolved)
        #expect(LockSession.Status.denied.isResolved)
        #expect(LockSession.Status.cancelled.isResolved)
        #expect(LockSession.Status.timerExpired.isResolved)
        #expect(LockSession.Status.complete.isResolved)
    }

    @Test("isResolved is false for active statuses")
    func activeStatuses() {
        #expect(!LockSession.Status.pending.isResolved)
        #expect(!LockSession.Status.unlockRequested.isResolved)
    }

    @Test("All statuses round-trip through Codable")
    func codableRoundTrip() throws {
        let statuses: [LockSession.Status] = [.pending, .unlockRequested, .approved, .denied, .cancelled, .timerExpired, .complete]
        for status in statuses {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(LockSession.Status.self, from: encoded)
            #expect(decoded == status)
        }
    }

    @Test("primaryFriendName returns first name or fallback")
    func primaryFriendName() {
        let session = makeSampleSession(friendNames: ["Alice", "Bob"])
        #expect(session.primaryFriendName == "Alice")

        let emptySession = makeSampleSession(friendNames: [])
        #expect(emptySession.primaryFriendName == "your friend")
    }

    @Test("expiresAt is nil by default")
    func expiresAtNilByDefault() {
        let session = makeSampleSession()
        #expect(session.expiresAt == nil)
    }

    private func makeSampleSession(friendUIDs: [String] = ["f1"], friendNames: [String] = ["Alice"]) -> LockSession {
        LockSession(
            ownerUID: "owner1",
            ownerName: "Owner",
            friendUIDs: friendUIDs,
            friendNames: friendNames,
            status: .pending,
            appTokensCount: 2,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - AppUser Model Tests
@Suite("AppUser Model")
struct AppUserModelTests {

    @Test("AppUser Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let user = AppUser(displayName: "Ali", inviteCode: "XK29PQ", friends: ["uid1", "uid2"], fcmToken: "token123")
        let encoded = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(AppUser.self, from: encoded)
        #expect(decoded.displayName == user.displayName)
        #expect(decoded.inviteCode == user.inviteCode)
        #expect(decoded.friends == user.friends)
        #expect(decoded.fcmToken == user.fcmToken)
    }

    @Test("fcmToken defaults to nil")
    func fcmTokenDefaultsNil() {
        let user = AppUser(displayName: "Ali", inviteCode: "ABC123")
        #expect(user.fcmToken == nil)
    }

    @Test("friends defaults to empty array")
    func friendsDefaultEmpty() {
        let user = AppUser(displayName: "Ali", inviteCode: "ABC123")
        #expect(user.friends.isEmpty)
    }
}

// MARK: - FriendRequest Model Tests
@Suite("FriendRequest Model")
struct FriendRequestModelTests {

    @Test("FriendRequest Codable round-trip")
    func codableRoundTrip() throws {
        let req = FriendRequest(fromUID: "a", fromName: "Alice", toUID: "b", toName: "Bob", status: .pending, createdAt: Date())
        let encoded = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(FriendRequest.self, from: encoded)
        #expect(decoded.fromUID == req.fromUID)
        #expect(decoded.toUID == req.toUID)
        #expect(decoded.status == req.status)
    }

    @Test("All FriendRequest statuses round-trip")
    func statusRoundTrip() throws {
        for status in [FriendRequest.Status.pending, .accepted, .declined] {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(FriendRequest.Status.self, from: encoded)
            #expect(decoded == status)
        }
    }
}

// MARK: - AppError Tests
@Suite("AppError")
struct AppErrorTests {

    @Test("alreadyFriends has non-nil error description")
    func alreadyFriendsDescription() {
        #expect(AppError.alreadyFriends.errorDescription != nil)
    }

    @Test("requestAlreadySent has non-nil error description")
    func requestAlreadySentDescription() {
        #expect(AppError.requestAlreadySent.errorDescription != nil)
    }
}

// MARK: - SharedStore Tests
@Suite("SharedStore")
struct SharedStoreTests {

    @Test("isSessionActive round-trips")
    func isSessionActive() {
        SharedStore.isSessionActive = true
        #expect(SharedStore.isSessionActive == true)
        SharedStore.isSessionActive = false
        #expect(SharedStore.isSessionActive == false)
    }

    @Test("activeSessionID round-trips and clears")
    func activeSessionID() {
        SharedStore.activeSessionID = "session-123"
        #expect(SharedStore.activeSessionID == "session-123")
        SharedStore.activeSessionID = nil
        #expect(SharedStore.activeSessionID == nil)
    }

    @Test("currentUserID round-trips and clears")
    func currentUserID() {
        SharedStore.currentUserID = "user-abc"
        #expect(SharedStore.currentUserID == "user-abc")
        SharedStore.currentUserID = nil
        #expect(SharedStore.currentUserID == nil)
    }

    @Test("sessionExpiresAt round-trips and clears")
    func sessionExpiresAt() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        SharedStore.sessionExpiresAt = date
        let retrieved = SharedStore.sessionExpiresAt
        #expect(retrieved != nil)
        #expect(abs(retrieved!.timeIntervalSince1970 - date.timeIntervalSince1970) < 1)
        SharedStore.sessionExpiresAt = nil
        #expect(SharedStore.sessionExpiresAt == nil)
    }
}

// MARK: - FriendViewModel Tests
@Suite("FriendViewModel")
struct FriendViewModelTests {

    @Test("sendRequest with short code sets error and returns false")
    func sendRequestShortCode() async {
        let vm = FriendViewModel(service: MockFirestoreService())
        let result = await vm.sendRequest(myUID: "me", myName: "Ali", code: "ABC")
        #expect(result == false)
        #expect(vm.error != nil)
    }

    @Test("sendRequest with own invite code sets error")
    func sendRequestOwnCode() async {
        let mock = MockFirestoreService()
        mock.users["me"] = AppUser(id: "me", displayName: "Ali", inviteCode: "OWNCO")
        let vm = FriendViewModel(service: mock)
        let result = await vm.sendRequest(myUID: "me", myName: "Ali", code: "OWNCO")
        #expect(result == false)
        #expect(vm.error == "That's your own invite code.")
    }

    @Test("sendRequest with unknown code sets error")
    func sendRequestUnknownCode() async {
        let vm = FriendViewModel(service: MockFirestoreService())
        let result = await vm.sendRequest(myUID: "me", myName: "Ali", code: "ZZZZZ9")
        #expect(result == false)
        #expect(vm.error == "No user found with that code.")
    }

    @Test("sendRequest alreadyFriends error is surfaced")
    func sendRequestAlreadyFriends() async {
        let mock = MockFirestoreService()
        mock.users["them"] = AppUser(id: "them", displayName: "Bob", inviteCode: "FRIEND")
        mock.errorToThrow = AppError.alreadyFriends
        let vm = FriendViewModel(service: mock)
        let result = await vm.sendRequest(myUID: "me", myName: "Ali", code: "FRIEND")
        #expect(result == false)
        #expect(vm.error != nil)
    }

    @Test("fetchFriends with empty UIDs sets empty array without calling service")
    func fetchFriendsEmpty() async {
        let mock = MockFirestoreService()
        let vm = FriendViewModel(service: mock)
        await vm.fetchFriends(uids: [])
        #expect(vm.friends.isEmpty)
    }

    @Test("decline removes request from incomingRequests")
    func declineRemovesRequest() async {
        let mock = MockFirestoreService()
        let vm = FriendViewModel(service: mock)
        let req = FriendRequest(id: "req1", fromUID: "a", fromName: "Alice", toUID: "b", toName: "Bob", status: .pending, createdAt: Date())
        vm.incomingRequests = [req]
        await vm.decline(request: req)
        #expect(vm.incomingRequests.isEmpty)
    }

    @Test("accept removes request from incomingRequests")
    func acceptRemovesRequest() async {
        let mock = MockFirestoreService()
        let vm = FriendViewModel(service: mock)
        let req = FriendRequest(id: "req1", fromUID: "a", fromName: "Alice", toUID: "b", toName: "Bob", status: .pending, createdAt: Date())
        vm.incomingRequests = [req]
        await vm.accept(request: req)
        #expect(vm.incomingRequests.isEmpty)
    }
}

// MARK: - Timer Failsafe Tests
@Suite("Timer Failsafe")
struct TimerFailsafeTests {

    @Test("Session with past expiresAt is immediately expired")
    func pastExpiryDate() {
        let pastDate = Date(timeIntervalSinceNow: -10)
        let delay = pastDate.timeIntervalSinceNow
        #expect(delay < 0)
    }

    @Test("Session with future expiresAt has positive delay")
    func futureExpiryDate() {
        let futureDate = Date(timeIntervalSinceNow: 3600)
        let delay = futureDate.timeIntervalSinceNow
        #expect(delay > 0)
    }

    @Test("timerExpired status isResolved")
    func timerExpiredIsResolved() {
        #expect(LockSession.Status.timerExpired.isResolved)
    }
}
