import SwiftUI
import CoreData

struct JoinHouseholdView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var inviteCode = ""
    @State private var userName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedAvatarColor = "blue"
    @State private var isJoining = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var useCloudSync = true
    
    let avatarColors = ["blue", "green", "orange", "purple", "red", "pink", "yellow", "indigo"]
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Household.name, ascending: true)],
        animation: .default)
    private var households: FetchedResults<Household>
    
    var body: some View {
        NavigationView {
            Form {
                Section("Invitation Code") {
                    TextField("6-digit code", text: $inviteCode)
                        .textCase(.uppercase)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .onChange(of: inviteCode) { oldValue, newValue in
                            inviteCode = String(newValue.prefix(6)).uppercased()
                        }
                }
                
                Section("Account Setup") {
                    TextField("Your Name", text: $userName)
                        .autocapitalization(.words)
                    
                    TextField("Email Address", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                
                Section("Avatar") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose your avatar color")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(avatarColors, id: \.self) { color in
                                Button(action: { selectedAvatarColor = color }) {
                                    Circle()
                                        .fill(Color(color))
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedAvatarColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                        .overlay(
                                            Text(String(userName.prefix(1).uppercased()))
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                Section("Sync Options") {
                    Toggle("Use Cloud Sync", isOn: $useCloudSync)
                    
                    if useCloudSync {
                        Text("This will sync your household data across all your devices using CloudKit.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("This will only store data locally on this device.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it works:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Enter the 6-digit invitation code")
                            Text("2. Create your account with email and password")
                            Text("3. Choose an avatar color")
                            Text("4. Join the household!")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Join Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isJoining)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Join") {
                        Task {
                            await joinHousehold()
                        }
                    }
                    .disabled(!isFormValid || isJoining)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        return inviteCode.count == 6 &&
               !userName.isEmpty &&
               authManager.isValidEmail(email) &&
               authManager.isValidPassword(password) &&
               password == confirmPassword
    }
    
    private func joinHousehold() async {
        isJoining = true
        
        do {
            // First, register the user
            let newUser = try await authManager.registerUser(email: email, password: password, name: userName)
            newUser.avatarColor = selectedAvatarColor
            
            // TODO: Re-enable CloudKit sync when CloudSyncManager is properly integrated
            // if useCloudSync {
            //     if let household = try await cloudSync.joinHouseholdFromInvite(code: inviteCode) {
            //         ActivityTracker.shared.trackMemberJoined(user: newUser, household: household)
            //         await cloudSync.syncHousehold(household)
            //         GameificationManager.shared.currentUserPoints = newUser.points
            //         await MainActor.run { dismiss() }
            //     } else {
            //         await MainActor.run {
            //             errorMessage = cloudSync.syncError ?? "Failed to join household via cloud sync"
            //             showingError = true
            //         }
            //     }
            // } else {
                await joinHouseholdLocally(user: newUser)
            // }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isJoining = false
            }
        }
    }
    
    @MainActor
    private func joinHouseholdLocally(user: User) async {
        // Find household with matching invite code (local)
        guard let household = households.first(where: { $0.inviteCode == inviteCode }) else {
            errorMessage = "Invalid invitation code. Please check the code and try again."
            showingError = true
            isJoining = false
            return
        }
        
        // Create membership relationship
        let membership = UserHouseholdMembership(context: viewContext)
        membership.id = UUID()
        membership.user = user
        membership.household = household
        membership.role = "member"
        membership.joinedAt = Date()
        
        // Update UserDefaults
        UserDefaults.standard.set(household.id?.uuidString, forKey: "currentHouseholdId")
        
        do {
            try viewContext.save()
            
            // Log the new member activity instead of using ActivityTracker
            LoggingManager.shared.info("New member joined household: \(user.name ?? "Unknown") joined \(household.name ?? "Unknown")", category: "Household")
            
            // Notify household members
            NotificationManager.shared.notifyNewMember(household: household, newMember: user)
            
            // Update GameificationManager
            GameificationManager.shared.currentUserPoints = user.points
            
            dismiss()
        } catch {
            errorMessage = "Failed to join household. Please try again."
            showingError = true
            isJoining = false
        }
    }
}

struct JoinHouseholdView_Previews: PreviewProvider {
    static var previews: some View {
        JoinHouseholdView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AuthenticationManager.shared)
    }
}