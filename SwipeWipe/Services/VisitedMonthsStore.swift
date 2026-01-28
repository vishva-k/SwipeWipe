import Foundation

@MainActor
final class VisitedMonthsStore: ObservableObject {
    @Published private(set) var visited: Set<String> = []
    private let key = "visited_month_ids"

    init() {
        if let arr = UserDefaults.standard.array(forKey: key) as? [String] {
            visited = Set(arr)
        }
    }

    func isVisited(_ id: String) -> Bool {
        visited.contains(id)
    }

    func markVisited(_ id: String) {
        visited.insert(id)
        UserDefaults.standard.set(Array(visited), forKey: key)
    }

    func resetAll() {
        visited.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }
}
