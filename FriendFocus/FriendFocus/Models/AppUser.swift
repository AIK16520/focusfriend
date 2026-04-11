import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    var displayName: String
    var inviteCode: String
    var friends: [String] = []
    var fcmToken: String?
    var createdAt: Date = Date()

    /// Explicit memberwise init so tests can supply a pre-set id.
    init(id: String? = nil, displayName: String, inviteCode: String, friends: [String] = [], fcmToken: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.inviteCode = inviteCode
        self.friends = friends
        self.fcmToken = fcmToken
        self.createdAt = createdAt
    }
}
