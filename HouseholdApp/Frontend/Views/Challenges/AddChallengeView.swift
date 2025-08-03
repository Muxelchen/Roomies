import SwiftUI
import CoreData

struct AddChallengeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var points = 50
    @State private var target = 7
    @State private var duration = 7
    @State private var challengeType: ChallengeType = .taskCompletion
    
    enum ChallengeType: String, CaseIterable {
        case taskCompletion = "Aufgaben erledigen"
        case streak = "Streak halten"
        case points = "Punkte sammeln"
        case custom = "Benutzerdefiniert"
        
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
                Section("Challenge-Details") {
                    TextField("Titel", text: $title)
                    
                    TextField("Beschreibung", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Typ & Ziel") {
                    Picker("Challenge-Typ", selection: $challengeType) {
                        ForEach(ChallengeType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    
                    HStack {
                        Text("Ziel")
                        Spacer()
                        Stepper("\(target)", value: $target, in: 1...100)
                    }
                    
                    HStack {
                        Text("Dauer (Tage)")
                        Spacer()
                        Stepper("\(duration)", value: $duration, in: 1...30)
                    }
                }
                
                Section("Belohnung") {
                    HStack {
                        Text("Punkte")
                        Spacer()
                        Stepper("\(points)", value: $points, in: 10...500, step: 10)
                    }
                }
                
                Section {
                    Text("Die Challenge startet sofort nach der Erstellung und läuft \(duration) Tage.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Neue Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        createChallenge()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func createChallenge() {
        withAnimation {
            let newChallenge = Challenge(context: viewContext)
            newChallenge.id = UUID()
            newChallenge.title = title
            newChallenge.challengeDescription = description
            newChallenge.points = Int32(points)
            newChallenge.target = Int32(target)
            newChallenge.progress = 0
            newChallenge.type = challengeType.rawValue
            newChallenge.isActive = true
            newChallenge.createdAt = Date()
            newChallenge.startDate = Date()
            newChallenge.endDate = Calendar.current.date(byAdding: .day, value: duration, to: Date())
            
            // TODO: Assign to current household
            
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