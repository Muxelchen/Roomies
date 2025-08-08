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
        case members = "Members"
        case invitations = "Invitations"
        case settings = "Settings"
    }
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Household.name, ascending: true)],
        animation: .default)
    private var households: FetchedResults<Household>
    
    var currentHousehold: Household? {
        households.first // In a real app, you'd track the current household ID
    }
    
    var body: some View {
        // ✅ FIX: Remove NavigationView to prevent nesting conflicts
        ZStack {
            PremiumScreenBackground(sectionColor: .dashboard, style: .minimal)
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
        }
        .navigationTitle("Manage Household")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }
            
            if currentHousehold != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Create New Household") {
                            showingCreateHousehold = true
                        }
                        Button("Join Household") {
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

struct HouseholdHeaderView: View {
    let household: Household
    
    var body: some View {
        VStack(spacing: 12) {
            Text(household.name ?? "Unknown Household")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(household.memberships?.count ?? 0)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(household.tasks?.count ?? 0)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Tasks")
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                )
        )
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
            
            Button("Invite Member") {
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
                                    Text(member.name ?? "Unknown")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("\(member.points) Points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Member")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let joinDate = member.createdAt {
                    Text("since \(formatDate(joinDate))")
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
                Text("Invite Code")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack {
                    Text(household.inviteCode ?? "ERROR")
                        .font(.title)
                        .fontWeight(.bold)
                        .tracking(2)
                    
                    Button(action: copyInviteCode) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: Color.blue.opacity(0.15), radius: 8, x: 0, y: 4)
                )
                
                Text("Share this code with friends and family")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.blue.opacity(0.15), radius: 10, x: 0, y: 6)
            )
            
            // Share Options
            VStack(spacing: 12) {
                Button("Show QR Code") {
                    PremiumAudioHapticSystem.playModalPresent()
                    showingQRCode = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue)
                .cornerRadius(25)
                
                Button("Share Invitation") {
                    PremiumAudioHapticSystem.playButtonTap(style: .medium)
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
        PremiumAudioHapticSystem.playSuccess()
        LoggingManager.shared.info("Invite code copied to clipboard", category: LoggingManager.Category.general.rawValue)
    }
    
    private func shareInvite() {
        let inviteText = "Join my household! Code: \(household.inviteCode ?? "") - Download the Household Manager App: https://apps.apple.com/app/household-manager"
        
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
            Section("Household Settings") {
                TextField("Name", text: $householdName)
                    .onSubmit {
                        updateHouseholdName()
                    }
            }
            
            Section("Actions") {
                Button("Leave Household") {
                    PremiumAudioHapticSystem.playButtonTap(style: .medium)
                    leaveHousehold()
                }
                .foregroundColor(.orange)
                
                Button("Delete Household") {
                    showingDeleteAlert = true
                }
                .foregroundColor(.red)
            }
        }
        .alert("Delete Household", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteHousehold()
            }
        } message: {
            Text("This action cannot be undone. All tasks and challenges will be deleted.")
        }
    }
    
    private func updateHouseholdName() {
        guard !householdName.isEmpty && householdName != household.name else { return }
        
        household.name = householdName
        
        do {
            try household.managedObjectContext?.save()
            LoggingManager.shared.info("Household name updated to: \(householdName)", category: LoggingManager.Category.general.rawValue)
        } catch {
            LoggingManager.shared.error("Failed to update household name", category: LoggingManager.Category.general.rawValue, error: error)
            // Revert the change
            householdName = household.name ?? ""
        }
    }
    
    private func deleteHousehold() {
        guard let context = household.managedObjectContext else { return }
        
        // Delete the household (Core Data will handle cascade deletions)
        context.delete(household)
        
        do {
            try context.save()
            LoggingManager.shared.info("Household deleted successfully", category: LoggingManager.Category.general.rawValue)
            
            // Clear current user's household reference
            UserDefaults.standard.removeObject(forKey: "currentHouseholdId")
            
        } catch {
            LoggingManager.shared.error("Failed to delete household", category: LoggingManager.Category.general.rawValue, error: error)
        }
    }

    private func leaveHousehold() {
        // Remove current user's membership from this household
        if let currentUser = IntegratedAuthenticationManager.shared.currentUser,
           let memberships = household.memberships?.allObjects as? [UserHouseholdMembership],
           let membership = memberships.first(where: { $0.user == currentUser }),
           let context = household.managedObjectContext {
            context.delete(membership)
            do {
                try context.save()
                LoggingManager.shared.info("User left household", category: LoggingManager.Category.general.rawValue)
                UserDefaults.standard.removeObject(forKey: "currentHouseholdId")
            } catch {
                LoggingManager.shared.error("Failed to leave household", category: LoggingManager.Category.general.rawValue, error: error)
            }
        }
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
                    Text("No Household")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Create a new household or join an existing one")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 16) {
                Button("Create Household") {
                    showingCreateHousehold = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue)
                .cornerRadius(25)
                
                Button("Join Household") {
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