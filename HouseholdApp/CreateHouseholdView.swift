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
                    Text("You will automatically become the administrator of the new household.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Create Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createHousehold()
                    }
                    .disabled(householdName.isEmpty || userName.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createHousehold() {
        isCreating = true
        
        withAnimation {
            // Create new user
            let newUser = User(context: viewContext)
            newUser.id = UUID()
            newUser.name = userName
            newUser.email = "" // TODO: Add email input if needed
            newUser.avatarColor = selectedAvatarColor
            newUser.points = 0
            newUser.createdAt = Date()
            
            // Create new household
            let newHousehold = Household(context: viewContext)
            newHousehold.id = UUID()
            newHousehold.name = householdName
            newHousehold.inviteCode = generateInviteCode()
            newHousehold.createdAt = Date()
            
            // Create membership relationship
            let membership = UserHouseholdMembership(context: viewContext)
            membership.id = UUID()
            membership.user = newUser
            membership.household = newHousehold
            membership.role = "admin"
            membership.isActive = true
            membership.joinedAt = Date()
            
            // Save current user info
            UserDefaults.standard.set(newUser.id?.uuidString, forKey: "currentUserId")
            UserDefaults.standard.set(userName, forKey: "currentUserName")
            UserDefaults.standard.set(selectedAvatarColor, forKey: "currentUserAvatarColor")
            UserDefaults.standard.set(newHousehold.id?.uuidString, forKey: "currentHouseholdId")
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                print("Error creating household: \(error)")
                isCreating = false
            }
        }
    }
    
    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

struct CreateHouseholdView_Previews: PreviewProvider {
    static var previews: some View {
        CreateHouseholdView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}