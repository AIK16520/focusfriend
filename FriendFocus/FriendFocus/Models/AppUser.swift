import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    var displayName: String
    var inviteCode: String
    var friends: [String] = []    // array of UIDs
    var createdAt: Date = Date()
}
