import SwiftUI

struct InviteMemberView: View {
    let household: Household
    @Environment(\.dismiss) private var dismiss
    @State private var showingQRCode = false
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumScreenBackground(sectionColor: .dashboard, style: .minimal)
                VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("Invite Member")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Invite friends and family to '\(household.name ?? "your household")'")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Invite Code Display
                VStack(spacing: 16) {
                    Text("Invitation Code")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text(household.inviteCode ?? "ERROR")
                            .font(.title)
                            .fontWeight(.bold)
                            .tracking(2)
                        
                    Button(action: copyInviteCode) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: Color.blue.opacity(0.15), radius: 8, x: 0, y: 4)
                    )
                    
                    Text("Code copied!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .opacity(0) // Will be animated when copying
                }
                
                // Action Buttons
                VStack(spacing: 16) {
                    PremiumButton("Show QR Code", icon: "qrcode", sectionColor: .dashboard) {
                        PremiumAudioHapticSystem.playModalPresent()
                        showingQRCode = true
                    }
                    
                    PremiumButton("Share Invitation", icon: "square.and.arrow.up", sectionColor: .dashboard) {
                        PremiumAudioHapticSystem.playButtonTap(style: .medium)
                        shareInvite()
                    }
                }
                
                Spacer()
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("How it works:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Share the code or QR code")
                        Text("2. The person downloads the app")
                        Text("3. On first start, the code is entered")
                        Text("4. Automatic join to household")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
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
            .sheet(isPresented: $showingQRCode) {
                QRCodeView(inviteCode: household.inviteCode ?? "")
            }
        }
    }
    
    private func copyInviteCode() {
        UIPasteboard.general.string = household.inviteCode
        PremiumAudioHapticSystem.playSuccess()
    }
    
    private func shareInvite() {
        let inviteText = """
        Join my household '\(household.name ?? "")'!
        
        Invitation code: \(household.inviteCode ?? "")
        
        Download the Household Manager App:
        https://apps.apple.com/app/household-manager
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [inviteText],
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.rootViewController?.view
            popover.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
}

struct InviteMemberView_Previews: PreviewProvider {
    static var previews: some View {
        InviteMemberView(household: createSampleHousehold())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
    
    static func createSampleHousehold() -> Household {
        let context = PersistenceController.preview.container.viewContext
        let sampleHousehold = Household(context: context)
        sampleHousehold.id = UUID()
        sampleHousehold.name = "Sample Family"
        sampleHousehold.inviteCode = "ABC12345"
        sampleHousehold.createdAt = Date()
        return sampleHousehold
    }
}