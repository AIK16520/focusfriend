import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var friendVM: FriendViewModel
    @State private var selectedFriend: AppUser?
    @State private var showFriendPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if let session = sessionVM.activeSession {
                    ActiveSessionView(session: session)
                } else {
                    newSessionView
                }
            }
            .navigationTitle("Ficus")
        }
    }

    // MARK: – New session setup

    private var newSessionView: some View {
        VStack(spacing: 20) {
            // Friend picker card
            VStack(alignment: .leading, spacing: 10) {
                Label("Lock guardian", systemImage: "person.fill.checkmark")
                    .font(.headline)

                if friendVM.friends.isEmpty {
                    Text("Add a friend in the Friends tab first.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        showFriendPicker = true
                    } label: {
                        HStack {
                            Text(selectedFriend?.displayName ?? "Choose a friend…")
                                .foregroundStyle(selectedFriend == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            if let error = sessionVM.error {
                Text(error).foregroundStyle(.red).font(.footnote)
            }

            Spacer()

            Button {
                guard let owner = auth.currentUser, let friend = selectedFriend else { return }
                Task { await sessionVM.startSession(owner: owner, friend: friend) }
            } label: {
                if sessionVM.isStartingSession {
                    ProgressView()
                } else {
                    Text("Start Lock Session")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedFriend == nil || sessionVM.isStartingSession)
        }
        .padding()
        .confirmationDialog("Choose a friend", isPresented: $showFriendPicker, titleVisibility: .visible) {
            ForEach(friendVM.friends) { friend in
                Button(friend.displayName) { selectedFriend = friend }
            }
        }
    }
}
