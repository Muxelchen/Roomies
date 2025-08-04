import SwiftUI
import CoreData

struct CreateHouseholdView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var householdName = ""
    @State private var userName = ""
    @State private var selectedAvatarColor = "blue"
    @State private var isCreating = false
    
    let avatarColors = ["blue", "green", "orange", "purple", "red", "pink", "yellow", "indigo"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Household Details") {
                    TextField("Household Name", text: $householdName)
                        .autocapitalization(.words)
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
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedAvatarColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Household")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createHousehold) {
                        if isCreating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(householdName.isEmpty || userName.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createHousehold() {
        isCreating = true
        
        withAnimation {
            // Create new household
            let newHousehold = Household(context: viewContext)
            newHousehold.id = UUID()
            newHousehold.name = householdName
            newHousehold.inviteCode = generateInviteCode()
            newHousehold.createdAt = Date()
            
            // Create new user with proper authentication data
            let newUser = User(context: viewContext)
            newUser.id = UUID()
            newUser.name = userName
            newUser.email = "\(userName.lowercased().replacingOccurrences(of: " ", with: "."))@household.local"
            // ✅ FIX: Use AuthenticationManager for password hashing instead of local import
            newUser.hashedPassword = AuthenticationManager.shared.hashPassword("household123")
            newUser.avatarColor = selectedAvatarColor
            newUser.points = 100 // Starting points for new household creator
            newUser.createdAt = Date()
            
            // Create membership relationship
            let membership = UserHouseholdMembership(context: viewContext)
            membership.id = UUID()
            membership.user = newUser
            membership.household = newHousehold
            membership.role = "admin"
            membership.joinedAt = Date()
            
            // Save current user info
            UserDefaults.standard.set(newUser.id?.uuidString, forKey: "currentUserId")
            UserDefaults.standard.set(userName, forKey: "currentUserName")
            UserDefaults.standard.set(selectedAvatarColor, forKey: "currentUserAvatarColor")
            UserDefaults.standard.set(newHousehold.id?.uuidString, forKey: "currentHouseholdId")
            
            do {
                try viewContext.save()
                
                // ✅ FIX: Properly authenticate the newly created household user
                AuthenticationManager.shared.currentUser = newUser
                AuthenticationManager.shared.isAuthenticated = true
                
                // Also store in keychain for persistence
                AuthenticationManager.shared.keychain.savePassword("household123", for: newUser.email!)
                UserDefaults.standard.set(newUser.email, forKey: "currentUserEmail")
                
                dismiss()
            } catch {
                print("Error creating household: \(error)")
                isCreating = false
            }
        }
    }
    
    // ✅ FIX: Generate unique invite code with collision detection
    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var code: String
        var isUnique = false
        
        repeat {
            code = String((0..<6).map { _ in characters.randomElement()! })
            
            // Check if this code already exists
            let request: NSFetchRequest<Household> = Household.fetchRequest()
            request.predicate = NSPredicate(format: "inviteCode == %@", code)
            
            do {
                let existingHouseholds = try viewContext.fetch(request)
                isUnique = existingHouseholds.isEmpty
            } catch {
                print("Error checking invite code uniqueness: \(error)")
                // If we can't check, assume it's unique to avoid infinite loop
                isUnique = true
            }
        } while !isUnique
        
        return code
    }
}

struct CreateHouseholdView_Previews: PreviewProvider {
    static var previews: some View {
        CreateHouseholdView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}