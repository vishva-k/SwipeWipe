import SwiftUI
import PhotosUI
import Photos

struct PickedPhoto: Identifiable {
    let id: String            // PHAsset local identifier
    let image: UIImage
}

struct ContentView: View {
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var photos: [PickedPhoto] = []

    @State private var index: Int = 0

    // assets the user marked to delete
    @State private var toDelete: Set<String> = []

    // swipe animation state
    @State private var dragOffset: CGSize = .zero

    // end flow
    @State private var showSummary: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var deleting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                if photos.isEmpty {
                    emptyState
                } else if showSummary || index >= photos.count {
                    summaryView
                } else {
                    swipeDeck
                }
            }
            .navigationTitle("SwipeWipe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 300,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Image(systemName: "photo.on.rectangle.angled")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        index = 0
                        toDelete.removeAll()
                        dragOffset = .zero
                        showSummary = false
                    }
                    .disabled(photos.isEmpty)
                }
            }
            .onChange(of: pickerItems) { _, newItems in
                Task { await loadPhotos(from: newItems) }
            }
            .alert("Delete selected photos?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteMarkedPhotos() }
                }
            } message: {
                Text("This will move \(toDelete.count) photo(s) to Recently Deleted.")
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 44))
            Text("Pick a month’s photos")
                .font(.title2)
            Text("Swipe left to mark for deletion, right to keep. You’ll confirm at the end.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding()
    }

    private var swipeDeck: some View {
        ZStack {
            if index + 1 < photos.count {
                CardView(image: photos[index + 1].image)
                    .scaleEffect(0.96)
                    .opacity(0.9)
                    .padding(.horizontal, 18)
            }

            CardView(image: photos[index].image)
                .overlay(alignment: .topLeading) {
                    if toDelete.contains(photos[index].id) {
                        Label("Marked", systemImage: "trash")
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(16)
                    }
                }
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width) / 20))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            let x = value.translation.width
                            let threshold: CGFloat = 120

                            if x <= -threshold {
                                markDeleteAndAdvance()
                            } else if x >= threshold {
                                keepAndAdvance()
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    dragOffset = .zero
                                }
                            }
                        }
                )
                .padding(.horizontal, 18)
        }
        .overlay(alignment: .bottom) {
            footer.padding(.bottom, 24)
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                markDeleteAndAdvance()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Text("\(min(index + 1, max(photos.count, 1))) / \(photos.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 90)

            Button {
                keepAndAdvance()
            } label: {
                Label("Keep", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    private var summaryView: some View {
        VStack(spacing: 12) {
            Text("Review")
                .font(.title2)

            Text("Kept: \(photos.count - toDelete.count) • Marked: \(toDelete.count)")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Go Back") {
                    showSummary = false
                    if index >= photos.count { index = max(photos.count - 1, 0) }
                }
                .buttonStyle(.bordered)

                Button {
                    showDeleteConfirm = true
                } label: {
                    if deleting {
                        ProgressView()
                    } else {
                        Text("Delete Marked")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(toDelete.isEmpty || deleting)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    private func keepAndAdvance() {
        animateSwipe(toRight: true) {
            advance()
        }
    }

    private func markDeleteAndAdvance() {
        let id = photos[index].id
        toDelete.insert(id)

        animateSwipe(toRight: false) {
            advance()
        }
    }

    private func advance() {
        index += 1
        if index >= photos.count {
            showSummary = true
        }
    }

    private func animateSwipe(toRight: Bool, completion: @escaping () -> Void) {
        let endX: CGFloat = toRight ? 700 : -700
        withAnimation(.easeInOut(duration: 0.18)) {
            dragOffset = CGSize(width: endX, height: 40)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dragOffset = .zero
            completion()
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        photos.removeAll()
        index = 0
        toDelete.removeAll()
        showSummary = false
        dragOffset = .zero

        for item in items {
            // IMPORTANT: this is the PHAsset local identifier
            guard let id = item.itemIdentifier else { continue }

            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                photos.append(PickedPhoto(id: id, image: image))
            }
        }
    }

    private func deleteMarkedPhotos() async {
        deleting = true
        defer { deleting = false }

        // Request read/write permission (will show system prompt if needed)
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            errorMessage = "Photo access wasn’t granted. Enable it in Settings > Privacy & Security > Photos."
            return
        }

        let ids = Array(toDelete)
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(fetchResult)
            }

            // remove deleted items from our local list
            let deletedSet = Set(ids)
            photos.removeAll { deletedSet.contains($0.id) }
            toDelete.removeAll()
            index = 0
            showSummary = true

        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }
}

private struct CardView: View {
    let image: UIImage

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .frame(height: 520)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(radius: 10, y: 6)
    }
}

#Preview {
    ContentView()
}
