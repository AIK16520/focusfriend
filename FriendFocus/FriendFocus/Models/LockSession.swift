import Foundation
import FirebaseFirestore

struct LockSession: Codable, Identifiable {
    @DocumentID var id: String?
    var ownerUID: String
    var ownerName: String
    var friendUID: String
    var friendName: String
    var status: Status
    var appTokensCount: Int     // count only — actual tokens live in SharedStore (App Group)
    var createdAt: Date
    var updatedAt: Date
    var resolvedAt: Date?

    enum Status: String, Codable {
        case pending            // locked, friend just informed — no action needed yet
        case unlockRequested    // owner tapped "Request Unlock" — friend must approve/deny
        case approved           // friend approved → block lifted
        case denied             // friend denied  → block stays (owner has emergency stop)
        case cancelled          // owner force-stopped → block lifted
        case complete           // terminal, archived

        var isResolved: Bool {
            switch self {
            case .approved, .denied, .cancelled, .complete: return true
            case .pending, .unlockRequested: return false
            }
        }
    }
}
