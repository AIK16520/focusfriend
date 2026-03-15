import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var auth: AuthService
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "figure.2.arms.open")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Welcome to Ficus")
                    .font(.largeTitle.bold())
                Text("Your friends keep you focused.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                TextField("Your name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { signIn() }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Button(action: signIn) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    private func signIn() {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { errorMessage = "Enter your name to continue."; return }
        isLoading = true
        errorMessage = nil
        Task {
            do { try await auth.signIn(displayName: name) }
            catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }
}
