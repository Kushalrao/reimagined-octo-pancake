import SwiftUI

@main
struct StationCardApp: App {
    init() {
        // start the first cards' web processes and scenes before the first screen is even built; the rest load as they scroll in
        for card in Cards.all.prefix(TrainWebViewHost.maxLive) { TrainWebViewHost.host(id: card.id).warm(phase: card.phase, station: false, livery: card.livery) }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
