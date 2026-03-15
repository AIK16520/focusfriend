import SwiftUI

// Presented as a sheet on the friend's device when an incoming lock request arrives.
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
                Image(systemName: "lock.fill").foregroundStyle(.orange)
                Text("\(session.ownerName) wants to lock")
                    .font(.headline)
            }

            Text("\(session.appTokensCount) app\(session.appTokensCount == 1 ? "" : "s") blocked")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            Text("Started \(session.createdAt, format: .relative(presentation: .named))")
                .font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Approve") {
                    act { await sessionVM.approve(session: session) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isActing)

                Button("Deny") {
                    act { await sessionVM.deny(session: session) }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(isActing)

                if isActing { ProgressView() }
            }
        }
        .padding(.vertical, 6)
    }

    private func act(action: @escaping () async -> Void) {
        isActing = true
        Task {
            await action()
            isActing = false
        }
    }
}
