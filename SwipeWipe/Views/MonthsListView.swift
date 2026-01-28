import SwiftUI

struct MonthsListView: View {
    @EnvironmentObject private var vm: LibraryViewModel
    @EnvironmentObject private var visited: VisitedMonthsStore

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("SwipeWipe")
        }
        .task {
            if vm.buckets.isEmpty && !vm.isLoading {
                vm.loadMonths()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView("Loading months…")
        } else if let error = vm.errorMessage {
            VStack(spacing: 12) {
                Text(error)
                Button("Try Again") { vm.loadMonths() }
            }
            .padding()
        } else {
            List(vm.buckets) { bucket in
                NavigationLink {
                    MonthReviewView(bucket: bucket)
                } label: {
                    HStack {
                        Text(bucket.title)
                            .font(.headline)
                            .foregroundStyle(visited.isVisited(bucket.id) ? .red : .primary)

                        Spacer()

                        Text("\(bucket.assetCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
