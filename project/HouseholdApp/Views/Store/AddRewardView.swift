import SwiftUI
import CoreData

struct AddRewardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    @State private var name = ""
    @State private var description = ""
    @State private var cost = 50
    @State private var isActive = true
    @State private var selectedIcon = "gift.fill" // ✅ FIX: Add missing state for icon selection
    
    // Add FocusState to manage keyboard focus
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var descriptionFieldFocused: Bool
    
    let availableIcons = [
        "gift.fill", "ice.cream", "popcorn.fill", "gamecontroller.fill",
        "tv.fill", "music.note", "book.fill", "car.fill",
        "airplane", "camera.fill", "heart.fill", "star.fill"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Reward Details") {
                    TextField("Reward Name", text: $name)
                        .focused($nameFieldFocused)
                        .onSubmit {
                            nameFieldFocused = false
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
                
                Section("Cost & Icon") {
                    HStack {
                        Text("Cost (Points)")
                        Spacer()
                        Stepper("\(cost)", value: $cost, in: 1...1000, step: 5)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? .white : .blue)
                                        .frame(width: 44, height: 44)
                                        .background(selectedIcon == icon ? Color.blue : Color.blue.opacity(0.1))
                                        .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                Section("Settings") {
                    Toggle("Active", isOn: $isActive)
                }
                
                Section {
                    Text("This reward will be available to all household members.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Reward")
            .navigationBarTitleDisplayMode(.inline)
            .onSubmit {
                if !name.isEmpty {
                    saveReward()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localizedString("common.cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localizedString("common.save")) {
                        saveReward()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside text fields
            nameFieldFocused = false
            descriptionFieldFocused = false
            hideKeyboard()
        }
    }
    
    // Add function to hide keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func saveReward() {
        withAnimation {
            let newReward = Reward(context: viewContext)
            newReward.id = UUID()
            newReward.name = name
            newReward.rewardDescription = description.isEmpty ? nil : description
            newReward.cost = Int32(cost)
            newReward.createdAt = Date()
            
            // ✅ FIX: Improved household assignment logic using correct relationship name
            if let currentUser = AuthenticationManager.shared.currentUser {
                // First try to get household from current user's memberships
                if let memberships = currentUser.householdMemberships?.allObjects as? [UserHouseholdMembership],
                   let household = memberships.first?.household {
                    newReward.household = household
                    LoggingManager.shared.info("Reward assigned to household: \(household.name ?? "Unknown")", category: LoggingManager.Category.general.rawValue)
                } else {
                    // Fallback: Try to find any household the user might belong to
                    let householdRequest: NSFetchRequest<Household> = Household.fetchRequest()
                    do {
                        let households = try viewContext.fetch(householdRequest)
                        if let household = households.first {
                            newReward.household = household
                            LoggingManager.shared.info("Reward assigned to fallback household: \(household.name ?? "Unknown")", category: LoggingManager.Category.general.rawValue)
                        } else {
                            LoggingManager.shared.warning("No household found - reward created without household assignment", category: LoggingManager.Category.general.rawValue)
                        }
                    } catch {
                        LoggingManager.shared.error("Failed to find household for reward", category: LoggingManager.Category.general.rawValue, error: error)
                    }
                }
            } else {
                LoggingManager.shared.warning("No current user - reward created without household assignment", category: LoggingManager.Category.general.rawValue)
            }
            
            // Set active status
            newReward.isAvailable = isActive
            
            do {
                try viewContext.save()
                LoggingManager.shared.info("Reward '\(name)' created successfully", category: LoggingManager.Category.general.rawValue)
                dismiss()
            } catch {
                LoggingManager.shared.error("Failed to save reward", category: LoggingManager.Category.general.rawValue, error: error)
            }
        }
    }
}

struct AddRewardView_Previews: PreviewProvider {
    static var previews: some View {
        AddRewardView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(LocalizationManager.shared)
    }
}