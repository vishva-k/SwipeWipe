import SwiftUI

@main
struct SwipeWipeApp: App {
    @StateObject private var visitedStore = VisitedMonthsStore()
    @StateObject private var libraryVM: LibraryViewModel

    init() {
        let store = VisitedMonthsStore()
        _visitedStore = StateObject(wrappedValue: store)
        _libraryVM = StateObject(wrappedValue: LibraryViewModel(visitedStore: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(visitedStore)
                .environmentObject(libraryVM)
        }
    }
}
