import SwiftUI

/// Root view: the kiln, the away-progress sheet, and background saves.
struct ContentView: View {
    @StateObject private var game = GameState.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        KilnView()
            .sheet(isPresented: awayBinding) {
                if let summary = game.awaySummary {
                    AwaySummaryView(summary: summary) {
                        game.dismissAwaySummary()
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    game.save()
                }
            }
    }

    private var awayBinding: Binding<Bool> {
        Binding(
            get: { game.awaySummary != nil },
            set: { if !$0 { game.dismissAwaySummary() } }
        )
    }
}
