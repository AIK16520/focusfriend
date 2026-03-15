import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        Group {
            if auth.isSignedIn {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.default, value: auth.isSignedIn)
    }
}
