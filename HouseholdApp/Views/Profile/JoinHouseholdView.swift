import SwiftUI
import CoreData

struct JoinHouseholdView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var inviteCode = ""
    @State private var userName = ""
    @State private var selectedAvatarColor = "blue"
    @State private var isJoining = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
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
                        .onChange(of: inviteCode) { newValue in
                            inviteCode = String(newValue.prefix(6)).uppercased()
                        }
                }
                
                Section("Your Profile") {
                    TextField("Your Name", text: $userName)
                        .autocapitalization(.words)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Avatar Color")
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
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it works:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Enter the 6-digit invitation code")
                            Text("2. Enter your name")
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
                        joinHousehold()
                    }
                    .disabled(inviteCode.count != 6 || userName.isEmpty || isJoining)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func joinHousehold() {
        isJoining = true
        
        // Find household with matching invite code
        guard let household = households.first(where: { $0.inviteCode == inviteCode }) else {
            errorMessage = "Invalid invitation code. Please check the code and try again."
            showingError = true
            isJoining = false
            return
        }
        
        withAnimation {
            // Create new user with proper authentication data
            let newUser = User(context: viewContext)
            newUser.id = UUID()
            newUser.name = userName
            newUser.email = "\(userName.lowercased().replacingOccurrences(of: " ", with: "."))@household.local"
            // ✅ FIX: Use AuthenticationManager for password hashing instead of local import
            newUser.hashedPassword = AuthenticationManager.shared.hashPassword("household123") // Default password for household users
            newUser.avatarColor = selectedAvatarColor
            newUser.points = 0
            newUser.createdAt = Date()
            
            // Create membership relationship
            let membership = UserHouseholdMembership(context: viewContext)
            membership.id = UUID()
            membership.user = newUser
            membership.household = household
            membership.role = "member"
            membership.joinedAt = Date()
            
            // Save current user info
            UserDefaults.standard.set(newUser.id?.uuidString, forKey: "currentUserId")
            UserDefaults.standard.set(userName, forKey: "currentUserName")
            UserDefaults.standard.set(selectedAvatarColor, forKey: "currentUserAvatarColor")
            UserDefaults.standard.set(household.id?.uuidString, forKey: "currentHouseholdId")
            
            do {
                try viewContext.save()
                
                // ✅ FIX: Properly authenticate the newly joined household user
                AuthenticationManager.shared.currentUser = newUser
                AuthenticationManager.shared.isAuthenticated = true
                
                // Also store in keychain for persistence
                AuthenticationManager.shared.keychain.savePassword("household123", for: newUser.email!)
                UserDefaults.standard.set(newUser.email, forKey: "currentUserEmail")
                
                dismiss()
            } catch {
                errorMessage = "Failed to join household. Please try again."
                showingError = true
                isJoining = false
            }
        }
    }
}

struct JoinHouseholdView_Previews: PreviewProvider {
    static var previews: some View {
        JoinHouseholdView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}