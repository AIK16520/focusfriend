import Foundation
import FirebaseFirestore

struct FriendRequest: Codable, Identifiable {
    @DocumentID var id: String?
    var fromUID: String
    var fromName: String
    var toUID: String
    var toName: String
    var status: Status
    var createdAt: Date

    enum Status: String, Codable {
        case pending, accepted, declined
    }

    /// Explicit memberwise init so tests can supply a pre-set id.
    init(id: String? = nil, fromUID: String, fromName: String, toUID: String, toName: String, status: Status, createdAt: Date) {
        self.id = id
        self.fromUID = fromUID
        self.fromName = fromName
        self.toUID = toUID
        self.toName = toName
        self.status = status
        self.createdAt = createdAt
    }
}
