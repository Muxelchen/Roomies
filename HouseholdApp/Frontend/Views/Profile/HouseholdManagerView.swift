import SwiftUI
import CoreData

struct HouseholdManagerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: HouseholdTab = .members
    @State private var showingCreateHousehold = false
    @State private var showingJoinHousehold = false
    @State private var inviteCode = ""
    
    enum HouseholdTab: String, CaseIterable {
        case members = "Mitglieder"
        case invitations = "Einladungen"
        case settings = "Einstellungen"
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Household.name, ascending: true)],
        animation: .default)
    private var households: FetchedResults<Household>
    
    var currentHousehold: Household? {
        households.first // In a real app, you'd track the current household ID
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let household = currentHousehold {
                    // Current Household Header
                    HouseholdHeaderView(household: household)
                    
                    // Tab Picker
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(HouseholdTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // Tab Content
                    switch selectedTab {
                    case .members:
                        MembersTabView(household: household)
                    case .invitations:
                        InvitationsTabView(household: household)
                    case .settings:
                        HouseholdSettingsTabView(household: household)
                    }
                } else {
                    // No Household State
                    NoHouseholdView(
                        showingCreateHousehold: $showingCreateHousehold,
                        showingJoinHousehold: $showingJoinHousehold
                    )
                }
            }
            .navigationTitle("Haushalt verwalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
                
                if currentHousehold != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Neuen Haushalt erstellen") {
                                showingCreateHousehold = true
                            }
                            Button("Haushalt beitreten") {
                                showingJoinHousehold = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateHousehold) {
                CreateHouseholdView()
            }
            .sheet(isPresented: $showingJoinHousehold) {
                JoinHouseholdView()
            }
        }
    }
}

struct HouseholdHeaderView: View {
    let household: Household
    
    var body: some View {
        VStack(spacing: 12) {
            Text(household.name ?? "Unbekannter Haushalt")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(household.memberships?.count ?? 0)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Mitglieder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(household.tasks?.count ?? 0)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Aufgaben")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(household.challenges?.count ?? 0)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Challenges")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
}

struct MembersTabView: View {
    let household: Household
    @State private var showingInviteSheet = false
    
    var members: [User] {
        (household.memberships?.allObjects as? [UserHouseholdMembership])?.compactMap { $0.user } ?? []
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(members, id: \.id) { member in
                    HouseholdMemberRowView(member: member)
                }
            }
            .listStyle(PlainListStyle())
            
            Button("Mitglied einladen") {
                showingInviteSheet = true
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.blue)
            .cornerRadius(25)
            .padding()
        }
        .sheet(isPresented: $showingInviteSheet) {
            InviteMemberView(household: household)
        }
    }
}

struct HouseholdMemberRowView: View {
    let member: User
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(member.avatarColor ?? "blue"))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(member.name?.prefix(1) ?? "?"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name ?? "Unbekannt")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("\(member.points) Punkte")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Mitglied")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let joinDate = member.createdAt {
                    Text("seit \(formatDate(joinDate))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct InvitationsTabView: View {
    let household: Household
    @State private var showingQRCode = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Invite Code Card
            VStack(spacing: 16) {
                Text("Einladungscode")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack {
                    Text(household.inviteCode ?? "FEHLER")
                        .font(.title)
                        .fontWeight(.bold)
                        .tracking(2)
                    
                    Button(action: copyInviteCode) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                Text("Teile diesen Code mit Freunden und Familie")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Share Options
            VStack(spacing: 12) {
                Button("QR-Code anzeigen") {
                    showingQRCode = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue)
                .cornerRadius(25)
                
                Button("Einladung teilen") {
                    shareInvite()
                }
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(25)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(inviteCode: household.inviteCode ?? "")
        }
    }
    
    private func copyInviteCode() {
        UIPasteboard.general.string = household.inviteCode
        // TODO: Show success toast
    }
    
    private func shareInvite() {
        let inviteText = "Tritt meinem Haushalt bei! Code: \(household.inviteCode ?? "") - Lade die Household Manager App herunter: https://apps.apple.com/app/household-manager"
        
        let activityViewController = UIActivityViewController(
            activityItems: [inviteText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
}

struct HouseholdSettingsTabView: View {
    let household: Household
    @State private var householdName: String
    @State private var showingDeleteAlert = false
    
    init(household: Household) {
        self.household = household
        self._householdName = State(initialValue: household.name ?? "")
    }
    
    var body: some View {
        Form {
            Section("Haushalt-Einstellungen") {
                TextField("Name", text: $householdName)
                    .onSubmit {
                        updateHouseholdName()
                    }
            }
            
            Section("Aktionen") {
                Button("Haushalt verlassen") {
                    // TODO: Leave household
                }
                .foregroundColor(.orange)
                
                Button("Haushalt löschen") {
                    showingDeleteAlert = true
                }
                .foregroundColor(.red)
            }
        }
        .alert("Haushalt löschen", isPresented: $showingDeleteAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                deleteHousehold()
            }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle Aufgaben und Challenges werden gelöscht.")
        }
    }
    
    private func updateHouseholdName() {
        // TODO: Update household name
    }
    
    private func deleteHousehold() {
        // TODO: Delete household
    }
}

struct NoHouseholdView: View {
    @Binding var showingCreateHousehold: Bool
    @Binding var showingJoinHousehold: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "house.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                
                VStack(spacing: 8) {
                    Text("Kein Haushalt")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Erstelle einen neuen Haushalt oder tritt einem bestehenden bei")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 16) {
                Button("Haushalt erstellen") {
                    showingCreateHousehold = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue)
                .cornerRadius(25)
                
                Button("Haushalt beitreten") {
                    showingJoinHousehold = true
                }
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(25)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct HouseholdManagerView_Previews: PreviewProvider {
    static var previews: some View {
        HouseholdManagerView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}