import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var friendVM: FriendViewModel
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if friendVM.isLoading && friendVM.friends.isEmpty {
                    ProgressView()
                } else if friendVM.friends.isEmpty {
                    ContentUnavailableView(
                        "No friends yet",
                        systemImage: "person.2",
                        description: Text("Add a friend using their 6-letter invite code.")
                    )
                } else {
                    List(friendVM.friends) { friend in
                        Label(friend.displayName, systemImage: "person.fill")
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Friend") { showAddSheet = true }
                }
            }
            .refreshable {
                let uids = auth.currentUser?.friends ?? []
                await friendVM.fetchFriends(uids: uids)
            }
            .sheet(isPresented: $showAddSheet) {
                AddFriendSheet(showAddSheet: $showAddSheet)
                    .environmentObject(auth)
                    .environmentObject(friendVM)
            }
        }
    }
}

private struct AddFriendSheet: View {
    @Binding var showAddSheet: Bool
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var friendVM: FriendViewModel
    @State private var code = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter your friend's 6-letter invite code.\nYou can find yours on the Profile tab.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                TextField("e.g. X7KP2Q", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.title3.monospaced())
                    .onChange(of: code) { _, new in
                        code = String(new.prefix(6)).uppercased()
                    }

                if let error = friendVM.error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }

                if showSuccess {
                    Label("Friend added!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Button("Add Friend") {
                    Task {
                        guard let uid = auth.uid else { return }
                        let ok = await friendVM.addFriend(myUID: uid, code: code)
                        if ok {
                            showSuccess = true
                            try? await Task.sleep(for: .seconds(1))
                            showAddSheet = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.count < 6 || friendVM.isLoading)

                Spacer()
            }
            .padding()
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddSheet = false }
                }
            }
        }
    }
}
