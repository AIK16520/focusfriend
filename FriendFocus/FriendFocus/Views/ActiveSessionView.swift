import SwiftUI

struct ActiveSessionView: View {
    let session: LockSession
    @EnvironmentObject var sessionVM: SessionViewModel

    var body: some View {
        VStack(spacing: 24) {
            statusCard

            Spacer()

            // Emergency stop — always visible so the owner is never truly stuck in Phase 2 mock mode
            if session.status == .pending || session.status == .denied {
                Button("Force Stop Session", role: .destructive) {
                    Task { await sessionVM.cancelSession() }
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            if session.status.isResolved {
                Button("Done") { sessionVM.dismissActiveSession() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle("Active Session")
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(spacing: 16) {
            switch session.status {
            case .pending:
                Image(systemName: "lock.fill")
                    .font(.system(size: 56)).foregroundStyle(.orange)
                Text("Waiting for \(session.friendName)…")
                    .font(.title3.bold())
                Text("They'll get notified and can approve your unlock.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                // Elapsed time
                Label(session.createdAt, systemImage: "clock")
                    .font(.footnote).foregroundStyle(.secondary)

            case .approved, .complete:
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 56)).foregroundStyle(.green)
                Text("Unlocked by \(session.friendName)")
                    .font(.title3.bold())
                Text("Your session has ended.")
                    .foregroundStyle(.secondary)

            case .denied:
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 56)).foregroundStyle(.red)
                Text("\(session.friendName) said no.")
                    .font(.title3.bold())
                Text("Stay focused. Use Force Stop if you have a genuine emergency.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)

            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 56)).foregroundStyle(.secondary)
                Text("Session cancelled.")
                    .font(.title3.bold())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

// Make Date directly usable in Label
private extension Label where Title == Text, Icon == Image {
    init(_ date: Date, systemImage: String) {
        self.init(date.formatted(.relative(presentation: .named)), systemImage: systemImage)
    }
}
