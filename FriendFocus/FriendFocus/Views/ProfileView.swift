import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @State private var showSignOutConfirm = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section("Identity") {
                    LabeledContent("Name", value: auth.currentUser?.displayName ?? "—")

                    HStack {
                        LabeledContent("Invite Code") {
                            Text(auth.currentUser?.inviteCode ?? "—")
                                .font(.body.monospaced())
                        }
                        Button {
                            UIPasteboard.general.string = auth.currentUser?.inviteCode
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.clipboard")
                                .foregroundStyle(copied ? .green : .blue)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Share this code with a friend so they can add you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showSignOutConfirm = true
                    }
                }
            }
            .navigationTitle("Profile")
            .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { try? auth.signOut() }
            }
        }
    }
}
