import Foundation
import Photos

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var buckets: [MonthBucket] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    let visitedStore: VisitedMonthsStore

    init(visitedStore: VisitedMonthsStore) {
        self.visitedStore = visitedStore
    }

    func loadMonths() {
        isLoading = true
        errorMessage = nil

        Task {
            let granted = await requestPhotoAccessIfNeeded()
            guard granted else {
                isLoading = false
                errorMessage = "Photo access not granted."
                return
            }

            // Heavy work off the main thread
            let result = await Task.detached(priority: .userInitiated) { () -> [MonthBucket] in
                let assets = PHAsset.fetchAssets(with: .image, options: nil)

                var countsByKey: [String: (year: Int, month: Int, count: Int)] = [:]

                assets.enumerateObjects { asset, _, _ in
                    guard let date = asset.creationDate else { return }
                    let comps = Calendar.current.dateComponents([.year, .month], from: date)
                    guard let year = comps.year, let month = comps.month else { return }

                    let key = String(format: "%04d-%02d", year, month)

                    if var existing = countsByKey[key] {
                        existing.count += 1
                        countsByKey[key] = existing
                    } else {
                        countsByKey[key] = (year: year, month: month, count: 1)
                    }
                }

                return countsByKey.values
                    .map { MonthBucket(year: $0.year, month: $0.month, assetCount: $0.count) }
                    .sorted { $0.monthDate > $1.monthDate } // newest first
            }.value

            // Back on main thread (we're @MainActor)
            self.buckets = result
            self.isLoading = false
        }
    }

    // MARK: - Permissions

    private func requestPhotoAccessIfNeeded() async -> Bool {
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            switch status {
            case .authorized, .limited:
                return true
            case .notDetermined:
                let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                return newStatus == .authorized || newStatus == .limited
            default:
                return false
            }
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            switch status {
            case .authorized:
                return true
            case .notDetermined:
                let newStatus = await withCheckedContinuation { cont in
                    PHPhotoLibrary.requestAuthorization { cont.resume(returning: $0) }
                }
                return newStatus == .authorized
            default:
                return false
            }
        }
    }
}
