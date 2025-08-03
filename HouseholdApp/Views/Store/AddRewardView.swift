import SwiftUI
import CoreData

struct AddRewardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    @State private var name = ""
    @State private var description = ""
    @State private var cost = 50
    @State private var selectedIcon = "gift.fill"
    @State private var isActive = true
    
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
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
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
    }
    
    private func saveReward() {
        withAnimation {
            let newReward = Reward(context: viewContext)
            newReward.id = UUID()
            newReward.name = name
            newReward.rewardDescription = description.isEmpty ? nil : description
            newReward.cost = Int32(cost)
            newReward.iconName = selectedIcon
            newReward.isActive = isActive
            newReward.createdAt = Date()
            
            // TODO: Associate with current household
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                print("Error saving reward: \(error)")
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