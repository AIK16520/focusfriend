import SwiftUI

// Presented as a sheet on the friend's device when an unlock is requested.
struct FriendRequestView: View {
    @EnvironmentObject var sessionVM: SessionViewModel

    var body: some View {
        NavigationStack {
            Group {
                if sessionVM.incomingRequests.isEmpty {
                    ContentUnavailableView(
                        "No Pending Requests",
                        systemImage: "tray",
                        description: Text("All requests have been resolved.")
                    )
                } else {
                    List(sessionVM.incomingRequests) { session in
                        RequestCard(session: session)
                            .environmentObject(sessionVM)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Lock Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { sessionVM.showingIncomingRequests = false }
                }
            }
        }
    }
}

private struct RequestCard: View {
    let session: LockSession
    @EnvironmentObject var sessionVM: SessionViewModel
    @State private var isActing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: session.status == .unlockRequested ? "lock.open" : "lock.fill")
                    .foregroundStyle(session.status == .unlockRequested ? .blue : .orange)
                Text(headerText)
                    .font(.headline)
            }

            Text("\(session.appTokensCount) app\(session.appTokensCount == 1 ? "" : "s") blocked")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            Text("Locked \(session.createdAt, format: .relative(presentation: .named))")
                .font(.caption).foregroundStyle(.secondary)

            if session.status == .unlockRequested {
                HStack(spacing: 12) {
                    Button("Unlock") {
                        act { await sessionVM.approve(session: session) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isActing)

                    Button("Stay Locked") {
                        act { await sessionVM.deny(session: session) }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isActing)

                    if isActing { ProgressView() }
                }
            } else {
                Text("Waiting — they'll notify you when they want to unlock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 6)
    }

    private var headerText: String {
        switch session.status {
        case .pending: return "\(session.ownerName) is locked 🔒"
        case .unlockRequested: return "\(session.ownerName) wants to unlock"
        default: return session.ownerName
        }
    }

    private func act(action: @escaping () async -> Void) {
        isActing = true
        Task {
            await action()
            isActing = false
        }
    }
}
