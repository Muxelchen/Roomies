import Foundation
import UIKit
import SwiftUI
import AVFoundation

// Namespace conflict resolution

class PhotoManager: NSObject, ObservableObject {
    static let shared = PhotoManager()
    
    @Published var capturedImage: UIImage?
    @Published var showingImagePicker = false
    @Published var showingCamera = false
    @Published var imagePickerSourceType: UIImagePickerController.SourceType = .camera
    
    private override init() {
        super.init()
    }
    
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            _Concurrency.Task { @MainActor in
                completion(granted)
            }
        }
    }
    
    func checkCameraAvailability() -> Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    func compressImage(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        let maxSizeBytes = maxSizeKB * 1024
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)
        
        while let data = imageData, data.count > maxSizeBytes && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
    
    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func saveTaskPhoto(_ image: UIImage, for taskId: UUID, type: PhotoType) -> Data? {
        // Resize image to max 800x600 for storage efficiency
        let targetSize = CGSize(width: 800, height: 600)
        guard let resizedImage = resizeImage(image, targetSize: targetSize) else {
            return nil
        }
        
        // Compress to max 500KB
        return compressImage(resizedImage, maxSizeKB: 500)
    }
    
    func loadImageFromData(_ data: Data) -> UIImage? {
        return UIImage(data: data)
    }
}

enum PhotoType {
    case before
    case after
    
    var title: String {
        switch self {
        case .before: return "Before Photo"
        case .after: return "After Photo"
        }
    }
    
    var description: String {
        switch self {
        case .before: return "Take a photo showing the current state"
        case .after: return "Take a photo showing the completed task"
        }
    }
}

// MARK: - UIImagePickerController Coordinator
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Camera Permission View
struct CameraPermissionView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    let onPermissionGranted: () -> Void
    let onPermissionDenied: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Camera Access Required")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("To take photos for task verification, please allow camera access.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Allow Camera Access") {
                PhotoManager.shared.requestCameraPermission { granted in
                    if granted {
                        onPermissionGranted()
                    } else {
                        onPermissionDenied()
                    }
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            
            Button("Maybe Later") {
                onPermissionDenied()
            }
            .font(.subheadline)
            .foregroundColor(.gray)
        }
        .padding()
    }
}