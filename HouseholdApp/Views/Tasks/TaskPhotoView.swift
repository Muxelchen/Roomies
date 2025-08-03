import SwiftUI
import CoreData

struct TaskPhotoView: View {
    let task: Task
    let photoType: PhotoType
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var showingCameraPermission = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .camera
    @State private var photoDescription = ""
    
    var currentPhotoData: Data? {
        switch photoType {
        case .before:
            return task.beforePhoto
        case .after:
            return task.afterPhoto
        }
    }
    
    var currentImage: UIImage? {
        guard let data = currentPhotoData else { return nil }
        return PhotoManager.shared.loadImageFromData(data)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Task Info
                    TaskInfoCardView(task: task)
                    
                    // Photo Section
                    PhotoSectionView()
                    
                    // Photo Description
                    PhotoDescriptionView()
                    
                    // Action Buttons
                    ActionButtonsView()
                }
                .padding()
            }
            .navigationTitle(photoType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                if selectedImage != nil || currentImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { savePhoto() }
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(
                    selectedImage: $selectedImage,
                    isPresented: $showingImagePicker,
                    sourceType: imagePickerSourceType
                )
            }
            .sheet(isPresented: $showingCameraPermission) {
                CameraPermissionView(
                    onPermissionGranted: {
                        showingCameraPermission = false
                        showingImagePicker = true
                    },
                    onPermissionDenied: {
                        showingCameraPermission = false
                    }
                )
            }
            .confirmationDialog("Select Photo Source", isPresented: $showingActionSheet) {
                if PhotoManager.shared.checkCameraAvailability() {
                    Button("Camera") {
                        imagePickerSourceType = .camera
                        PhotoManager.shared.requestCameraPermission { granted in
                            if granted {
                                showingImagePicker = true
                            } else {
                                showingCameraPermission = true
                            }
                        }
                    }
                }
                
                Button("Photo Library") {
                    imagePickerSourceType = .photoLibrary
                    showingImagePicker = true
                }
                
                if currentImage != nil {
                    Button("Remove Photo", role: .destructive) {
                        removePhoto()
                    }
                }
                
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    @ViewBuilder
    private func TaskInfoCardView(task: Task) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title ?? "Unknown Task")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let description = task.taskDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(photoType.description)
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func PhotoSectionView() -> some View {
        VStack(spacing: 12) {
            if let image = selectedImage ?? currentImage {
                // Display current/selected photo
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .clipped()
                
                Button("Change Photo") {
                    showingActionSheet = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                
            } else {
                // Photo placeholder
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text("No Photo Added")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text("Tap to add a photo for this task")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .onTapGesture {
                    showingActionSheet = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func PhotoDescriptionView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photo Notes (Optional)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("Add a description...", text: $photoDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
    }
    
    @ViewBuilder
    private func ActionButtonsView() -> some View {
        VStack(spacing: 12) {
            if selectedImage == nil && currentImage == nil {
                Button("Take Photo") {
                    showingActionSheet = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            if photoType == .after && (selectedImage != nil || currentImage != nil) {
                Button("Complete Task with Photo") {
                    completeTaskWithPhoto()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.green)
                .cornerRadius(12)
            }
        }
    }
    
    private func savePhoto() {
        guard let image = selectedImage else { return }
        
        withAnimation {
            if let photoData = PhotoManager.shared.saveTaskPhoto(image, for: task.id ?? UUID(), type: photoType) {
                switch photoType {
                case .before:
                    task.beforePhoto = photoData
                case .after:
                    task.afterPhoto = photoData
                }
                
                if !photoDescription.isEmpty {
                    task.photoDescription = photoDescription
                }
                
                do {
                    try viewContext.save()
                    dismiss()
                } catch {
                    print("Error saving photo: \(error)")
                }
            }
        }
    }
    
    private func removePhoto() {
        withAnimation {
            switch photoType {
            case .before:
                task.beforePhoto = nil
            case .after:
                task.afterPhoto = nil
            }
            
            do {
                try viewContext.save()
                selectedImage = nil
            } catch {
                print("Error removing photo: \(error)")
            }
        }
    }
    
    private func completeTaskWithPhoto() {
        savePhoto()
        
        // Mark task as completed
        withAnimation {
            task.isCompleted = true
            task.completedAt = Date()
            
            // Award points
            if let user = task.assignedTo {
                let points = GameificationManager.shared.calculateTaskPoints(for: task)
                GameificationManager.shared.awardPoints(
                    to: user,
                    points: points,
                    reason: "Task completed with photo verification"
                )
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                print("Error completing task: \(error)")
            }
        }
    }
}

struct TaskPhotoView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let task = Task(context: context)
        task.title = "Clean Kitchen"
        task.taskDescription = "Wipe counters, wash dishes, and sweep floor"
        
        return TaskPhotoView(task: task, photoType: .before)
            .environment(\.managedObjectContext, context)
            .environmentObject(LocalizationManager.shared)
    }
}