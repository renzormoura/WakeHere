import SwiftUI

/// Contêiner principal: abas + cobertura da viagem ativa + onboarding.
struct RootView: View {
    @EnvironmentObject private var root: CompositionRoot
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            TripPlanTab()
                .tabItem {
                    Label("Nova viagem", systemImage: "map.fill")
                }

            HistoryView()
                .tabItem {
                    Label("Histórico", systemImage: "clock.arrow.circlepath")
                }

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
        }
        // Viagem ativa cobre o app inteiro (State).
        .fullScreenCover(item: $root.session) { session in
            TripTrackingView(session: session)
        }
        .onAppear {
            if !hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            hasSeenOnboarding = true
        }) {
            OnboardingView()
        }
    }
}

/// Aba de planejamento: observa a ViewModel dona da CompositionRoot.
private struct TripPlanTab: View {
    @EnvironmentObject private var root: CompositionRoot

    var body: some View {
        TripPlanView(vm: root.planViewModel)
    }
}
