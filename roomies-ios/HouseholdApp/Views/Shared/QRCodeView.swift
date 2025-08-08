import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let inviteCode: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumScreenBackground(sectionColor: .dashboard, style: .minimal)
                VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Text("Scan QR Code")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Others can scan this QR code to join your household")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // QR Code
                if let qrImage = generateQRCode(from: "householdapp://join/\(inviteCode)") {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 250, height: 250)
                        .overlay(
                            Text("QR code could not be generated")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        )
                }
                
                // Invite Code Display
                VStack(spacing: 8) {
                    Text("Or enter code manually:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(inviteCode)
                        .font(.title)
                        .fontWeight(.bold)
                        .tracking(3)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                                )
                        )
                }
                
                    Spacer()
                }
            }
            .padding()
            .navigationTitle("Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        
        if let outputImage = filter.outputImage {
            // Scale up the image
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return nil
    }
}

struct QRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeView(inviteCode: "ABC123")
    }
}