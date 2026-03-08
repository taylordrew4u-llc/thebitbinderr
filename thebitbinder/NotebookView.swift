import SwiftUI
import PhotosUI
import SwiftData
import AVFoundation

extension FileManager {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

struct NotebookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var photos: [NotebookPhotoRecord]
    @AppStorage("roastModeEnabled") private var roastMode = false

    @State private var showingDetail: NotebookPhotoRecord?
    @State private var showingImagePicker = false
    @State private var pickedPhotoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var cameraImage: UIImage?
    
    private func delete(_ photo: NotebookPhotoRecord) {
        // Remove file from disk if it exists
        let url = FileManager.documentsDirectory.appendingPathComponent(photo.fileURL)
        try? FileManager.default.removeItem(at: url)
        // Remove from SwiftData
        modelContext.delete(photo)
        try? modelContext.save()
    }
    
    let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]
    
    var body: some View {
        NavigationStack {
            Group {
                if photos.isEmpty {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.notebookAccent.opacity(0.15), AppTheme.Colors.notebookAccent.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            Image(systemName: "book.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.notebookAccent, AppTheme.Colors.notebookAccent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(spacing: 8) {
                            Text("No pages saved yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Take photos of your physical joke notebook pages to keep a backup in the app")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(photos, id: \.id) { photo in
                                let imageURL = FileManager.documentsDirectory.appendingPathComponent(photo.fileURL)
                                CachedImageView(fileURL: imageURL,
                                                placeholder: AnyView(Color.gray.frame(minWidth: 100, minHeight: 100).overlay(Text("Loading").foregroundColor(.white))),
                                                contentMode: .fill,
                                                cornerRadius: 8)
                                    .frame(minWidth: 100, minHeight: 100)
                                    .clipped()
                                    .onTapGesture { showingDetail = photo }
                                    .contextMenu {
                                        Button(role: .destructive) { delete(photo) } label: { Label("Delete", systemImage: "trash") }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(roastMode ? "🔥 Fire Notebook" : "Notebook Saver")
            .toolbarBackground(
                roastMode ? AnyShapeStyle(AppTheme.Colors.roastSurface) : AnyShapeStyle(AppTheme.Colors.paperCream),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(roastMode ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $pickedPhotoItem,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        Label("Add Photo", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                }
            }
            .onChange(of: pickedPhotoItem) { oldValue, newValue in
                Task {
                    if let item = newValue {
                        await importPhoto(from: item)
                        pickedPhotoItem = nil
                    }
                }
            }
            .sheet(isPresented: $showingCamera, onDismiss: {
                if let cameraImage {
                    Task {
                        await saveCameraImage(cameraImage)
                    }
                    self.cameraImage = nil
                }
            }) {
                CameraView(image: $cameraImage)
            }
            .sheet(item: $showingDetail) { photo in
                NotebookDetailView(photo: photo)
                    .environment(\.modelContext, modelContext)
            }
            .onDisappear {
                // Clear image cache when leaving to free memory
                ImageCache.shared.clearCache()
            }
        }
    }
    
    private func importPhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            guard let uiImage = UIImage(data: data) else { return }
            
            let filename = uniqueFilename() + ".jpg"
            let url = FileManager.documentsDirectory.appendingPathComponent(filename)
            if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
                try jpegData.write(to: url, options: .atomic)
                let newPhoto = NotebookPhotoRecord(caption: "", fileURL: filename)
                await MainActor.run {
                    modelContext.insert(newPhoto)
                    try? modelContext.save()
                }
            }
        } catch {
            // ignore errors silently for now
        }
    }
    
    private func saveCameraImage(_ image: UIImage) async {
        let filename = uniqueFilename() + ".jpg"
        let url = FileManager.documentsDirectory.appendingPathComponent(filename)
        if let jpegData = image.jpegData(compressionQuality: 0.8) {
            do {
                try jpegData.write(to: url, options: .atomic)
                let newPhoto = NotebookPhotoRecord(caption: "", fileURL: filename)
                await MainActor.run {
                    modelContext.insert(newPhoto)
                    try? modelContext.save()
                }
            } catch {
                // ignore errors silently for now
            }
        }
    }
    
    private func uniqueFilename() -> String {
        UUID().uuidString
    }
}

struct NotebookDetailView: View {
    @Bindable var photo: NotebookPhotoRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    private func deleteCurrent() {
        // Remove file
        let url = FileManager.documentsDirectory.appendingPathComponent(photo.fileURL)
        try? FileManager.default.removeItem(at: url)
        // Delete model and dismiss
        modelContext.delete(photo)
        try? modelContext.save()
        dismiss()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                let imageURL = FileManager.documentsDirectory.appendingPathComponent(photo.fileURL)
                if let uiImage = UIImage(contentsOfFile: imageURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .padding()
                } else {
                    Color.gray
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(Text("Image not found").foregroundColor(.white))
                        .padding()
                }
                TextField("Caption", text: $photo.caption)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Notebook Page")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive) {
                        deleteCurrent()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - CameraView (UIKit wrapped)

#if !targetEnvironment(macCatalyst)
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        init(parent: CameraView) { self.parent = parent }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage { parent.image = uiImage }
            parent.dismiss()
        }
    }
}
#else
struct CameraView: View {
    @Binding var image: UIImage?
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("Camera is not available on Mac.\nUse the photo picker instead.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
}
#endif
