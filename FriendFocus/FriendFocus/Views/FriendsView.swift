import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var friendVM: FriendViewModel
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                // Incoming requests section
                if !friendVM.incomingRequests.isEmpty {
                    Section("Friend Requests") {
                        ForEach(friendVM.incomingRequests) { request in
                            FriendRequestRow(request: request)
                                .environmentObject(friendVM)
                        }
                    }
                }

                // Friends section
                Section {
                    if friendVM.friends.isEmpty {
                        Text("No friends yet. Send a request using their invite code.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    } else {
                        ForEach(friendVM.friends) { friend in
                            Label(friend.displayName, systemImage: "person.fill")
                        }
                    }
                } header: {
                    Text("Friends")
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
            .task {
                if let uid = auth.uid {
                    friendVM.startRequestListener(uid: uid)
                }
            }
        }
    }
}

private struct FriendRequestRow: View {
    let request: FriendRequest
    @EnvironmentObject var friendVM: FriendViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromName)
                    .font(.body)
                Text("Wants to be your friend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Accept") {
                Task { await friendVM.accept(request: request) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Decline") {
                Task { await friendVM.decline(request: request) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
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
                    Label("Request sent! Waiting for them to accept.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                        .font(.footnote)
                }

                Button("Send Request") {
                    Task {
                        guard let uid = auth.uid,
                              let name = auth.currentUser?.displayName else { return }
                        let ok = await friendVM.sendRequest(myUID: uid, myName: name, code: code)
                        if ok {
                            showSuccess = true
                            try? await Task.sleep(for: .seconds(1.5))
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
