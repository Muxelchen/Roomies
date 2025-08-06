import SwiftUI
import CoreData

struct CreateHouseholdView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var householdName = ""
    @State private var userName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedAvatarColor = "blue"
    @State private var useCloudSync = true
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let avatarColors = ["blue", "green", "orange", "purple", "red", "pink", "yellow", "indigo"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Household Details") {
                    TextField("Household Name", text: $householdName)
                        .autocapitalization(.words)
                }
                
                Section("Admin Account Setup") {
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
                        Text("What you'll get:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Unique 6-digit invitation code")
                            Text("• Admin privileges for your household")
                            Text("• Task management and point system")
                            Text("• Challenges and rewards system")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
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
                        Task {
                            await createHousehold()
                        }
                    }
                    .disabled(!isFormValid || isCreating)
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
        return !householdName.isEmpty &&
               !userName.isEmpty &&
               authManager.isValidEmail(email) &&
               authManager.isValidPassword(password) &&
               password == confirmPassword
    }
    
    private func createHousehold() async {
        isCreating = true
        
        do {
            // First, register the admin user
            let newUser = try await authManager.registerUser(email: email, password: password, name: userName)
            newUser.avatarColor = selectedAvatarColor
            
            // Create household
            let newHousehold = Household(context: viewContext)
            newHousehold.id = UUID()
            newHousehold.name = householdName
            newHousehold.inviteCode = generateInviteCode()
            newHousehold.createdAt = Date()
            
            // Create admin membership
            let membership = UserHouseholdMembership(context: viewContext)
            membership.id = UUID()
            membership.user = newUser
            membership.household = newHousehold
            membership.role = "admin"
            membership.joinedAt = Date()
            
            // Update UserDefaults
            UserDefaults.standard.set(newHousehold.id?.uuidString, forKey: "currentHouseholdId")
            
            try viewContext.save()
            
            // Update GameificationManager
            GameificationManager.shared.currentUserPoints = newUser.points
            
            // Create initial sample tasks for the household
            await createInitialTasks(household: newHousehold, user: newUser)
            
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isCreating = false
            }
        }
    }
    
    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        // FIXED: Safe unwrapping to prevent crashes
        return String((0..<6).compactMap { _ in characters.randomElement() })
    }
    
    private func createInitialTasks(household: Household, user: User) async {
        let initialTasks = [
            ("Welcome to your household!", "Get started by exploring the app features", 5, "Low"),
            ("Take out trash", "Empty all trash bins and take to curb", 10, "Medium"),
            ("Clean kitchen", "Wipe down counters and do dishes", 15, "Medium"),
            ("Vacuum living room", "Vacuum the main living area", 12, "Low")
        ]
        
        for (title, description, points, priority) in initialTasks {
            // FIXED: Safe unwrapping to prevent crashes
            guard let taskEntity = NSEntityDescription.entity(forEntityName: "HouseholdTask", in: viewContext),
                  let task = NSManagedObject(entity: taskEntity, insertInto: viewContext) as? HouseholdTask else {
                LoggingManager.shared.error("Failed to create HouseholdTask entity for initial tasks", category: "Household")
                continue
            }
            task.id = UUID()
            task.title = title
            task.taskDescription = description
            task.points = Int32(points)
            task.priority = priority
            task.isCompleted = false
            task.createdAt = Date()
            task.household = household
            task.assignedTo = user
        }
        
        do {
            try viewContext.save()
            LoggingManager.shared.info("Initial tasks created for new household", category: "Household")
        } catch {
            LoggingManager.shared.error("Failed to create initial tasks", category: "Household", error: error)
        }
    }
}

struct CreateHouseholdView_Previews: PreviewProvider {
    static var previews: some View {
        CreateHouseholdView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AuthenticationManager.shared)
    }
}