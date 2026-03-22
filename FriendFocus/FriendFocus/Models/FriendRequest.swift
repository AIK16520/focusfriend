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
}
