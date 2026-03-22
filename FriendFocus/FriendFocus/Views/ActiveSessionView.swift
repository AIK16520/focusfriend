import SwiftUI

struct ActiveSessionView: View {
    let session: LockSession
    @EnvironmentObject var sessionVM: SessionViewModel

    var body: some View {
        VStack(spacing: 24) {
            statusCard

            Spacer()

            // Request unlock — only shown while locked and not yet requested
            if session.status == .pending {
                Button {
                    Task { await sessionVM.requestUnlock() }
                } label: {
                    Label("Request Unlock", systemImage: "lock.open")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            // Emergency stop
            if session.status == .pending || session.status == .unlockRequested || session.status == .denied {
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
                Text("You're locked in 🔒")
                    .font(.title3.bold())
                Text("\(session.friendName) has been notified. Tap \"Request Unlock\" when you want out.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Label(session.createdAt, systemImage: "clock")
                    .font(.footnote).foregroundStyle(.secondary)

            case .unlockRequested:
                Image(systemName: "hourglass")
                    .font(.system(size: 56)).foregroundStyle(.orange)
                Text("Waiting on \(session.friendName)…")
                    .font(.title3.bold())
                Text("You've asked to unlock. They need to approve.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)

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

private extension Label where Title == Text, Icon == Image {
    init(_ date: Date, systemImage: String) {
        self.init(date.formatted(.relative(presentation: .named)), systemImage: systemImage)
    }
}
