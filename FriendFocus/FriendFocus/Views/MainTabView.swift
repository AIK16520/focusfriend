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
            // Start friend-side listener immediately so we catch incoming requests
            // even when the user is on a different tab.
            sessionVM.startFriendListener(uid: uid)
            // Hydrate the friends list
            let friendUIDs = auth.currentUser?.friends ?? []
            await friendVM.fetchFriends(uids: friendUIDs)
        }
    }
}
