import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthService
    @StateObject private var sessionVM = SessionViewModel()
    @StateObject private var friendVM = FriendViewModel()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2") }
                .badge(friendVM.incomingRequests.isEmpty ? 0 : friendVM.incomingRequests.count)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
        .environmentObject(sessionVM)
        .environmentObject(friendVM)
        // Friend-side incoming request sheet — shown whenever a pending session arrives
        .sheet(isPresented: $sessionVM.showingIncomingRequests) {
            FriendRequestView()
                .environmentObject(sessionVM)
        }
        .task {
            guard let uid = auth.uid else { return }
            sessionVM.startFriendListener(uid: uid)
            friendVM.startRequestListener(uid: uid)
            let friendUIDs = auth.currentUser?.friends ?? []
            await friendVM.fetchFriends(uids: friendUIDs)
        }
        .onReceive(auth.$currentUser) { user in
            Task { await friendVM.fetchFriends(uids: user?.friends ?? []) }
        }
    }
}
