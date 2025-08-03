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
                Section("Einladungscode") {
                    TextField("6-stelliger Code", text: $inviteCode)
                        .textCase(.uppercase)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .onChange(of: inviteCode) { newValue in
                            inviteCode = String(newValue.prefix(6)).uppercased()
                        }
                }
                
                Section("Dein Profil") {
                    TextField("Dein Name", text: $userName)
                        .autocapitalization(.words)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Avatar-Farbe")
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
                        Text("So funktioniert's:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1. Gib den 6-stelligen Einladungscode ein")
                            Text("2. Trage deinen Namen ein")
                            Text("3. Wähle eine Avatar-Farbe")
                            Text("4. Tritt dem Haushalt bei!")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Haushalt beitreten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .disabled(isJoining)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Beitreten") {
                        joinHousehold()
                    }
                    .disabled(inviteCode.count != 6 || userName.isEmpty || isJoining)
                }
            }
            .alert("Fehler", isPresented: $showingError) {
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
            errorMessage = "Ungültiger Einladungscode. Bitte überprüfe den Code und versuche es erneut."
            showingError = true
            isJoining = false
            return
        }
        
        withAnimation {
            // Create new user
            let newUser = User(context: viewContext)
            newUser.id = UUID()
            newUser.name = userName
            newUser.email = "" // TODO: Add email input if needed
            newUser.avatarColor = selectedAvatarColor
            newUser.points = 0
            newUser.createdAt = Date()
            
            // Create membership relationship
            let membership = UserHouseholdMembership(context: viewContext)
            membership.id = UUID()
            membership.user = newUser
            membership.household = household
            membership.role = "member"
            membership.isActive = true
            membership.joinedAt = Date()
            
            // Save current user info
            UserDefaults.standard.set(newUser.id?.uuidString, forKey: "currentUserId")
            UserDefaults.standard.set(userName, forKey: "currentUserName")
            UserDefaults.standard.set(selectedAvatarColor, forKey: "currentUserAvatarColor")
            UserDefaults.standard.set(household.id?.uuidString, forKey: "currentHouseholdId")
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                errorMessage = "Fehler beim Beitreten zum Haushalt. Bitte versuche es erneut."
                showingError = true
                isJoining = false
                print("Error joining household: \(error)")
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