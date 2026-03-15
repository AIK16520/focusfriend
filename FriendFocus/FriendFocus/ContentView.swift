// ContentView.swift
// Phase 1 UI: authorize → pick apps → start/stop session.
// No backend, no friend flow — local blocking only.

import SwiftUI
import FamilyControls

struct ContentView: View {
    @StateObject private var manager = BlockingManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if manager.authorizationStatus != .approved {
                    AuthorizationView(manager: manager)
                } else {
                    SessionView(manager: manager)
                }
            }
            .navigationTitle("FocusFriend")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: – Authorization screen

struct AuthorizationView: View {
    @ObservedObject var manager: BlockingManager

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            VStack(spacing: 10) {
                Text("Screen Time Access Required")
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)

                Text("FocusFriend uses Screen Time to block apps.\nThis must run on a physical device.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button("Grant Screen Time Access") {
                Task { await manager.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }
}

// MARK: – Session screen

struct SessionView: View {
    @ObservedObject var manager: BlockingManager

    var body: some View {
        VStack(spacing: 24) {

            // App picker card
            VStack(alignment: .leading, spacing: 10) {
                Label("Apps to Block", systemImage: "app.badge")
                    .font(.headline)

                let count = manager.selection.applicationTokens.count
                Text(count == 0 ? "No apps selected" : "\(count) app\(count == 1 ? "" : "s") selected")
                    .foregroundStyle(.secondary)

                Button("Choose Apps…") {
                    manager.showingPicker = true
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            Spacer()

            // Session control
            if manager.isSessionActive {
                VStack(spacing: 16) {
                    Label("Block Active", systemImage: "lock.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.green)

                    Text("Selected apps are blocked. Force-quitting this app will NOT lift the block.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button("Stop Session") {
                        manager.stopSession()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                }
            } else {
                Button("Start Session") {
                    manager.startSession()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(manager.selection.applicationTokens.isEmpty)
            }
        }
        .padding()
        // Present the system FamilyActivityPicker as a sheet.
        .sheet(isPresented: $manager.showingPicker) {
            NavigationStack {
                FamilyActivityPicker(selection: $manager.selection)
                    .navigationTitle("Choose Apps")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                SharedStore.saveSelection(manager.selection)
                                manager.showingPicker = false
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
