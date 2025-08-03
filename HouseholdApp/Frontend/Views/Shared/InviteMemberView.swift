import SwiftUI

struct InviteMemberView: View {
    let household: Household
    @Environment(\.dismiss) private var dismiss
    @State private var showingQRCode = false
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("Mitglied einladen")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Lade Freunde und Familie zu '\(household.name ?? "deinem Haushalt")' ein")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Invite Code Display
                VStack(spacing: 16) {
                    Text("Einladungscode")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text(household.inviteCode ?? "FEHLER")
                            .font(.title)
                            .fontWeight(.bold)
                            .tracking(2)
                        
                        Button(action: copyInviteCode) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    Text("Code kopiert!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .opacity(0) // Will be animated when copying
                }
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button("QR-Code anzeigen") {
                        showingQRCode = true
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue)
                    .cornerRadius(25)
                    
                    Button("Einladung teilen") {
                        shareInvite()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(25)
                }
                
                Spacer()
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("So funktioniert's:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Teile den Code oder QR-Code")
                        Text("2. Die Person lädt die App herunter")
                        Text("3. Beim ersten Start wird der Code eingegeben")
                        Text("4. Automatischer Beitritt zum Haushalt")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Einladung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
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
        // TODO: Show success animation/feedback
        if UserDefaults.standard.bool(forKey: "hapticFeedback") {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func shareInvite() {
        let inviteText = """
        Tritt meinem Haushalt '\(household.name ?? "")' bei!
        
        Einladungscode: \(household.inviteCode ?? "")
        
        Lade die Household Manager App herunter:
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
        // Create a proper sample household for preview
        let context = PersistenceController.preview.container.viewContext
        let sampleHousehold = Household(context: context)
        sampleHousehold.id = UUID()
        sampleHousehold.name = "Sample Family"
        sampleHousehold.inviteCode = "ABC123"
        sampleHousehold.createdAt = Date()
        
        return InviteMemberView(household: sampleHousehold)
            .environment(\.managedObjectContext, context)
    }
}