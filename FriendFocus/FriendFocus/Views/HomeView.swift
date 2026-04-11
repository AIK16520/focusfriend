import SwiftUI

struct HomeView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var friendVM: FriendViewModel
    @State private var selectedFriendIDs: Set<String> = []
    @State private var showFriendPicker = false
    @State private var maxDuration: TimeInterval? = nil

    private let durationOptions: [(label: String, value: TimeInterval?)] = [
        ("No limit", nil),
        ("30 min", 1800),
        ("1 hour", 3600),
        ("2 hours", 7200),
        ("4 hours", 14400)
    ]

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

    private var selectedFriends: [AppUser] {
        friendVM.friends.filter { selectedFriendIDs.contains($0.id ?? "") }
    }

    private var newSessionView: some View {
        VStack(spacing: 20) {
            // Friend picker
            VStack(alignment: .leading, spacing: 10) {
                Label("Lock guardians", systemImage: "person.fill.checkmark")
                    .font(.headline)

                if friendVM.friends.isEmpty {
                    Text("Add a friend in the Friends tab first.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button { showFriendPicker = true } label: {
                        HStack {
                            Text(selectedFriends.isEmpty ? "Choose friends…" : selectedFriends.map(\.displayName).joined(separator: ", "))
                                .foregroundStyle(selectedFriends.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
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

            // Timer picker
            VStack(alignment: .leading, spacing: 10) {
                Label("Max lock duration", systemImage: "timer")
                    .font(.headline)
                Picker("Duration", selection: $maxDuration) {
                    ForEach(durationOptions, id: \.label) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .pickerStyle(.segmented)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            if let error = sessionVM.error {
                Text(error).foregroundStyle(.red).font(.footnote)
            }

            Spacer()

            Button {
                guard let owner = auth.currentUser, !selectedFriends.isEmpty else { return }
                Task { await sessionVM.startSession(owner: owner, friends: selectedFriends, maxDurationSeconds: maxDuration) }
            } label: {
                if sessionVM.isStartingSession {
                    ProgressView()
                } else {
                    Text("Start Lock Session").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedFriends.isEmpty || sessionVM.isStartingSession)
        }
        .padding()
        .sheet(isPresented: $showFriendPicker) {
            FriendPickerSheet(selectedIDs: $selectedFriendIDs, friends: friendVM.friends)
        }
    }
}

private struct FriendPickerSheet: View {
    @Binding var selectedIDs: Set<String>
    let friends: [AppUser]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(friends) { friend in
                let uid = friend.id ?? ""
                HStack {
                    Text(friend.displayName)
                    Spacer()
                    if selectedIDs.contains(uid) {
                        Image(systemName: "checkmark").foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedIDs.contains(uid) { selectedIDs.remove(uid) }
                    else { selectedIDs.insert(uid) }
                }
            }
            .navigationTitle("Choose Guardians")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
