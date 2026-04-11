import Foundation
import FirebaseFirestore

struct LockSession: Codable, Identifiable {
    @DocumentID var id: String?
    var ownerUID: String
    var ownerName: String
    var friendUIDs: [String]
    var friendNames: [String]
    var status: Status
    var appTokensCount: Int
    var createdAt: Date
    var updatedAt: Date
    var resolvedAt: Date?
    var expiresAt: Date?
    var approvedByUID: String?
    var approvedByName: String?

    var primaryFriendName: String { friendNames.first ?? "your friend" }

    enum Status: String, Codable {
        case pending
        case unlockRequested
        case approved
        case denied
        case cancelled
        case timerExpired
        case complete

        var isResolved: Bool {
            switch self {
            case .approved, .denied, .cancelled, .timerExpired, .complete: return true
            case .pending, .unlockRequested: return false
            }
        }
    }
}
