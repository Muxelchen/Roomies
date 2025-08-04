import SwiftUI
import CoreData

struct AddChallengeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var duration = 7
    @State private var challengeType: ChallengeType = .taskCompletion
    
    // Add FocusState to manage keyboard focus
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var descriptionFieldFocused: Bool
    
    enum ChallengeType: String, CaseIterable {
        case taskCompletion = "Complete Tasks"
        case streak = "Maintain Streak"
        case points = "Collect Points"
        case custom = "Custom"
        
        var icon: String {
            switch self {
            case .taskCompletion: return "checkmark.circle"
            case .streak: return "flame"
            case .points: return "star"
            case .custom: return "gear"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Challenge Details") {
                    TextField("Title", text: $title)
                        .focused($titleFieldFocused)
                        .onSubmit {
                            titleFieldFocused = false
                            hideKeyboard()
                        }
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($descriptionFieldFocused)
                        .onSubmit {
                            descriptionFieldFocused = false
                            hideKeyboard()
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                if descriptionFieldFocused {
                                    Spacer()
                                    Button("Done") {
                                        descriptionFieldFocused = false
                                        hideKeyboard()
                                    }
                                }
                            }
                        }
                }
                
                Section("Type & Goal") {
                    Picker("Challenge Type", selection: $challengeType) {
                        ForEach(ChallengeType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    
                    HStack {
                        Text("Duration (Days)")
                        Spacer()
                        Stepper("\(duration)", value: $duration, in: 1...30)
                    }
                }
                
                Section {
                    Text("The challenge starts immediately after creation and runs for \(duration) days.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createChallenge()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside text fields
            titleFieldFocused = false
            descriptionFieldFocused = false
            hideKeyboard()
        }
    }
    
    // Add function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func createChallenge() {
        withAnimation {
            let newChallenge = Challenge(context: viewContext)
            newChallenge.id = UUID()
            newChallenge.title = title
            newChallenge.challengeDescription = description
            newChallenge.isActive = true
            newChallenge.createdAt = Date()
            newChallenge.dueDate = Calendar.current.date(byAdding: .day, value: duration, to: Date())
            
            // TODO: Assign to current household
            // Assign to current household if available
            if let currentUser = AuthenticationManager.shared.currentUser {
                // First try to get household from current user's memberships
                if let memberships = currentUser.householdMemberships?.allObjects as? [UserHouseholdMembership],
                   let household = memberships.first?.household {
                    newChallenge.household = household
                    print("✅ Challenge assigned to household: \(household.name ?? "Unknown")")
                } else {
                    // Fallback: Try to find any household the user might belong to
                    let householdRequest: NSFetchRequest<Household> = Household.fetchRequest()
                    do {
                        let households = try viewContext.fetch(householdRequest)
                        if let household = households.first {
                            newChallenge.household = household
                            print("✅ Challenge assigned to fallback household: \(household.name ?? "Unknown")")
                        } else {
                            print("⚠️ WARNING: No household found - challenge created without household assignment")
                        }
                    } catch {
                        print("❌ ERROR: Failed to find household: \(error)")
                    }
                }
            } else {
                print("⚠️ WARNING: No current user - challenge created without household assignment")
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                print("Error saving challenge: \(error)")
            }
        }
    }
}

struct AddChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        AddChallengeView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}