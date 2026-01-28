import SwiftUI
import Photos

struct MonthReviewView: View {
    let bucket: MonthBucket

    @EnvironmentObject private var visited: VisitedMonthsStore

    @State private var assets: [PHAsset] = []
    @State private var index: Int = 0

    // ids the user marked to delete
    @State private var toDelete: Set<String> = []

    // end flow
    @State private var showDeleteConfirm: Bool = false
    @State private var deleting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text(bucket.title)
                .font(.title2)
                .bold()

            if assets.isEmpty {
                ProgressView("Loading photos…")
            } else if index >= assets.count {
                summaryView
            } else {
                reviewView
            }
        }
        .padding()
        .navigationTitle(bucket.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAssetsForMonth()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var reviewView: some View {
        VStack(spacing: 12) {
            Text("Review")
            Text("Kept: \(assets.count - toDelete.count) • Marked: \(toDelete.count)")
                .foregroundStyle(.secondary)

            // Placeholder UI (you probably already have your swipe card UI)
            Text("Photo \(index + 1) / \(assets.count)")
                .font(.headline)

            HStack(spacing: 12) {
                Button("Keep") {
                    index += 1
                }
                .buttonStyle(.bordered)

                Button("Delete") {
                    let id = assets[index].localIdentifier
                    toDelete.insert(id)
                    index += 1
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var summaryView: some View {
        VStack(spacing: 12) {
            Text("Done with \(bucket.title)")
                .font(.headline)

            Text("Marked \(toDelete.count) for deletion.")
                .foregroundStyle(.secondary)

            Button(deleting ? "Deleting…" : "Delete Marked Photos") {
                showDeleteConfirm = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(toDelete.isEmpty || deleting)

            Button("Back to Months") {
                // mark this month as visited when finished
                visited.markVisited(bucket.id)
            }
            .buttonStyle(.bordered)
        }
        .confirmationDialog(
            "Delete \(toDelete.count) photos?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteMarked() }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func loadAssetsForMonth() async {
        // build the month date range
        var comps = DateComponents()
        comps.year = bucket.year
        comps.month = bucket.month
        comps.day = 1

        let cal = Calendar.current
        guard
            let start = cal.date(from: comps),
            let end = cal.date(byAdding: .month, value: 1, to: start)
        else { return }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: .image, options: options)

        var arr: [PHAsset] = []
        arr.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            arr.append(asset)
        }

        await MainActor.run {
            self.assets = arr
            self.index = 0
        }
    }

    private func deleteMarked() async {
        deleting = true
        errorMessage = nil

        let ids = Array(toDelete)
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(fetch)
            }

            await MainActor.run {
                deleting = false
                visited.markVisited(bucket.id)
            }
        } catch {
            await MainActor.run {
                deleting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
