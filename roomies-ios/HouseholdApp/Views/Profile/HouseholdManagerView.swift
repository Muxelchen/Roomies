import SwiftUI
import CoreData

struct HouseholdManagerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
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
                    InvitationsTabView(
                        household: household,
                        isAdmin: authManager.isCurrentUserHouseholdAdmin()
                    )
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
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    
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
            .premiumListAppearance()
            
            PremiumButton("Invite Member", icon: "person.badge.plus", sectionColor: .dashboard) {
                showingInviteSheet = true
            }
            .padding()
            .disabled(!authManager.isCurrentUserHouseholdAdmin())
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
    let isAdmin: Bool
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    @State private var pendingRequests: [JoinRequestViewModel] = []
    @State private var isLoading = false
    @State private var error: String = ""
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
                PremiumButton("Show QR Code", icon: "qrcode", sectionColor: .dashboard) {
                    PremiumAudioHapticSystem.playModalPresent()
                    showingQRCode = true
                }
                
                PremiumButton("Share Invitation", icon: "square.and.arrow.up", sectionColor: .dashboard) {
                    PremiumAudioHapticSystem.playButtonTap(style: .medium)
                    shareInvite()
                }
            }
            
            if isAdmin {
                // Pending Requests Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .foregroundColor(.blue)
                        Text("Pending Join Requests")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        if isLoading { ProgressView().scaleEffect(0.9) }
                    }
                    .padding(.horizontal, 4)

                    if !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if pendingRequests.isEmpty {
                        Text("No pending requests")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(pendingRequests) { req in
                            HStack {
                                Circle()
                                    .fill(Color(req.user.avatarColor ?? "blue"))
                                    .frame(width: 32, height: 32)
                                    .overlay(Text(String(req.user.name.prefix(1))).foregroundColor(.white).font(.footnote).bold())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(req.user.name)
                                        .font(.subheadline).fontWeight(.semibold)
                                    Text(req.user.email)
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                PremiumButton("Approve", icon: "checkmark.circle.fill", sectionColor: .dashboard) {
                                    Task { await approve(req) }
                                }
                                .buttonStyle(PremiumPressButtonStyle())
                                .frame(width: 120)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
                .onAppear { Task { await loadRequests() } }
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

    // MARK: - Pending Join Requests (Admin)
    struct JoinRequestViewModel: Identifiable { let id: String; let user: APIUser }
    @MainActor
    private func loadRequests() async {
        guard isAdmin, let hid = household.id?.uuidString else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await NetworkManager.shared.listJoinRequests(householdId: hid)
            let items = resp.data ?? []
            pendingRequests = items.map { JoinRequestViewModel(id: $0.id, user: $0.user) }
            error = ""
        } catch {
            self.error = error.localizedDescription
        }
    }
    @MainActor
    private func approve(_ req: JoinRequestViewModel) async {
        guard let hid = household.id?.uuidString else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await NetworkManager.shared.approveJoinRequest(householdId: hid, requestId: req.id)
            pendingRequests.removeAll { $0.id == req.id }
            PremiumAudioHapticSystem.playSuccess()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct HouseholdSettingsTabView: View {
    let household: Household
    @State private var householdName: String
    @State private var showingDeleteAlert = false
    @State private var leaving = false
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    
    init(household: Household) {
        self.household = household
        self._householdName = State(initialValue: household.name ?? "")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Pretty card for name editing
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill").foregroundColor(.blue)
                    Text("Household Settings").font(.headline).fontWeight(.semibold)
                }
                TextField("Household Name", text: $householdName)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit { updateHouseholdName() }
                PremiumButton("Save Name", icon: "square.and.pencil", sectionColor: .dashboard) {
                    PremiumAudioHapticSystem.playButtonTap(style: .medium)
                    updateHouseholdName()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                    )
            )

            // Actions card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "person.fill.xmark").foregroundColor(.orange)
                    Text("Actions").font(.headline).fontWeight(.semibold)
                }
                PremiumButton("Leave Household", icon: "rectangle.portrait.and.arrow.right", sectionColor: .dashboard) {
                    PremiumAudioHapticSystem.playButtonTap(style: .medium)
                    leaveHousehold()
                }
                .foregroundColor(.orange)
                .disabled(leaving)

                PremiumButton("Delete Household", icon: "trash.fill", sectionColor: .dashboard) {
                    showingDeleteAlert = true
                }
                .foregroundColor(.red)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.12), lineWidth: 1)
                    )
            )
            Spacer()
        }
        .padding()
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
                PremiumButton("Create Household", icon: "house.badge.plus", sectionColor: .dashboard) {
                    showingCreateHousehold = true
                }
                
                PremiumButton("Join Household", icon: "person.2.badge.plus", sectionColor: .dashboard) {
                    showingJoinHousehold = true
                }
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