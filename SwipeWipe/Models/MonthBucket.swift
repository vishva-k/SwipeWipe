import Foundation

struct MonthBucket: Identifiable, Hashable {
    // Use "YYYY-MM" as the id (ex: "2025-12")
    let id: String

    let year: Int
    let month: Int // 1...12
    let assetCount: Int

    // Convenience date for sorting (first day of month)
    let monthDate: Date

    var title: String {
        // "Dec 2025"
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: monthDate)
    }

    init(year: Int, month: Int, assetCount: Int) {
        self.year = year
        self.month = month
        self.assetCount = assetCount

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        self.monthDate = Calendar.current.date(from: comps) ?? Date.distantPast

        self.id = String(format: "%04d-%02d", year, month)
    }
}
