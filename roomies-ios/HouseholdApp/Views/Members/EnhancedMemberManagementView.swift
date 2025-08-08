import SwiftUI
import CoreData

struct EnhancedMemberManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: IntegratedAuthenticationManager
    @StateObject private var syncService = HouseholdSyncService.shared
    
    @State private var selectedTab: MemberTab = .members
    @State private var showingInviteSheet = false
    @State private var showingMemberActions = false
    @State private var selectedMember: User?
    @State private var searchText = ""
    @State private var showingCreateInviteSheet = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    enum MemberTab: String, CaseIterable {
        case members = "Members"
        case invitations = "Invitations"
        case administration = "Administration"
        
        var icon: String {
            switch self {
            case .members: return "person.2.fill"
            case .invitations: return "envelope.fill"
            case .administration: return "gear.circle.fill"
            }
        }
    }
    
    // Fetch current household
    @FetchRequest private var households: FetchedResults<Household>
    
    init() {
        _households = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Household.createdAt, ascending: false)],
            predicate: nil
        )
    }
    
    private var currentHousehold: Household? {
        // Get the user's current household
        guard let currentUser = authManager.currentUser,
              let memberships = currentUser.householdMemberships?.allObjects as? [UserHouseholdMembership] else {
            return nil
        }
        return memberships.first?.household
    }
    
    private var householdMembers: [User] {
        guard let household = currentHousehold,
              let memberships = household.memberships?.allObjects as? [UserHouseholdMembership] else {
            return []
        }
        
        let members = memberships.compactMap { $0.user }
        
        // Filter by search text if provided
        if searchText.isEmpty {
            return members.sorted { ($0.name ?? "") < ($1.name ?? "") }
        } else {
            return members
                .filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
                .sorted { ($0.name ?? "") < ($1.name ?? "") }
        }
    }
    
    private var isCurrentUserAdmin: Bool {
        guard let currentUser = authManager.currentUser,
              let household = currentHousehold,
              let memberships = household.memberships?.allObjects as? [UserHouseholdMembership] else {
            return false
        }
        
        return memberships.first { $0.user == currentUser }?.role == "admin"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                PremiumScreenBackground(sectionColor: .dashboard, style: .minimal)
                VStack(spacing: 0) {
                if let household = currentHousehold {
                    // Household Header
                    householdHeaderView(household)
                    
                    // Tab Picker
                    tabPickerView
                    
                    // Main Content
                    switch selectedTab {
                    case .members:
                        membersTabContent
                    case .invitations:
                        invitationsTabContent
                    case .administration:
                        administrationTabContent
                    }
                } else {
                    noHouseholdView
                }
            }
            .navigationTitle("Member Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { 
                        PremiumAudioHapticSystem.playModalDismiss()
                        dismiss() 
                    }
                }
                
                if currentHousehold != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Invite Members") {
                                PremiumAudioHapticSystem.playModalPresent()
                                showingInviteSheet = true
                            }
                            
                            if isCurrentUserAdmin {
                                Button("Create Invite Link") {
                                    PremiumAudioHapticSystem.playButtonTap(style: .medium)
                                    showingCreateInviteSheet = true
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingInviteSheet) {
            InviteMemberSheet(household: currentHousehold)
                .accessibilityIdentifier("InviteMemberSheet")
        }
        .sheet(isPresented: $showingCreateInviteSheet) {
            CreateInviteSheet(household: currentHousehold)
                .accessibilityIdentifier("CreateInviteSheet")
        }
            .actionSheet(isPresented: $showingMemberActions) {
            memberActionSheet
        }
        .onAppear {
            // Establish real-time connection for member updates
            if let household = currentHousehold {
                syncService.joinHouseholdRoom(householdId: household.id?.uuidString ?? "")
            }
        }
        .overlay(
            Group {
                if isLoading {
                    LoadingOverlay()
                }
            }
        )
    }
    
    // MARK: - View Components
    
    private func householdHeaderView(_ household: Household) -> some View {
        VStack(spacing: 12) {
            Text(household.name ?? "Unknown Household")
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            
            HStack(spacing: 30) {
                StatisticView(
                    title: "Members",
                    value: "\(householdMembers.count)",
                    icon: "person.2.fill",
                    color: .blue
                )
                
                StatisticView(
                    title: "Tasks",
                    value: "\(household.tasks?.count ?? 0)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatisticView(
                    title: "Connection",
                    value: syncService.isConnected ? "Live" : "Offline",
                    icon: syncService.isConnected ? "wifi" : "wifi.slash",
                    color: syncService.isConnected ? .green : .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
    
    private var tabPickerView: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(MemberTab.allCases, id: \.self) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .onChange(of: selectedTab) { _, _ in
            PremiumAudioHapticSystem.playFilterSwitch(context: .taskFilterChange)
        }
    }
    
    private var membersTabContent: some View {
        VStack(spacing: 0) {
            // Search Bar
            SearchBar(text: $searchText, placeholder: "Search members...")
                .padding(.horizontal)
            
            // Members List
            List {
                ForEach(householdMembers, id: \.id) { member in
                    EnhancedMemberRowView(
                        member: member,
                        currentUser: authManager.currentUser,
                        isAdmin: isCurrentUserAdmin,
                        onMemberTapped: { selectedMember in
                            self.selectedMember = selectedMember
                            showingMemberActions = true
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(PlainListStyle())
            
            if householdMembers.isEmpty {
                EmptyStateView(
                    icon: "person.2.slash",
                    title: "No Members Found",
                    message: searchText.isEmpty ? "No members in household" : "No members match your search"
                )
            }
        }
    }
    
    private var invitationsTabContent: some View {
        VStack(spacing: 20) {
            if let household = currentHousehold {
                // Invite Code Card
                InviteCodeCardView(household: household)
                
                // Share Options
                VStack(spacing: 16) {
                    ShareButton(
                        title: "Share Invite Code",
                        icon: "square.and.arrow.up",
                        action: { shareInviteCode(household.inviteCode ?? "") }
                    )
                    
                    ShareButton(
                        title: "Copy to Clipboard",
                        icon: "doc.on.doc",
                        action: { copyInviteCode(household.inviteCode ?? "") }
                    )
                    
                    if isCurrentUserAdmin {
                        ShareButton(
                            title: "Generate New Code",
                            icon: "arrow.clockwise",
                            style: .secondary,
                            action: { regenerateInviteCode() }
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .padding()
    }
    
    private var administrationTabContent: some View {
        VStack {
            if isCurrentUserAdmin {
                List {
                    AdminSection(
                        title: "Member Management",
                        items: [
                            AdminItem(title: "View Member Details", icon: "person.text.rectangle", action: {}),
                            AdminItem(title: "Manage Roles", icon: "person.badge.key", action: {}),
                            AdminItem(title: "Remove Members", icon: "person.badge.minus", action: {})
                        ]
                    )
                    
                    AdminSection(
                        title: "Household Settings",
                        items: [
                            AdminItem(title: "Edit Household Name", icon: "house.circle", action: {}),
                            AdminItem(title: "Privacy Settings", icon: "lock.circle", action: {}),
                            AdminItem(title: "Notification Settings", icon: "bell.circle", action: {})
                        ]
                    )
                    
                    AdminSection(
                        title: "Advanced",
                        items: [
                            AdminItem(title: "Export Data", icon: "square.and.arrow.up", action: {}),
                            AdminItem(title: "Delete Household", icon: "trash.circle", color: .red, action: {})
                        ]
                    )
                }
                .listStyle(InsetGroupedListStyle())
            } else {
                EmptyStateView(
                    icon: "lock.shield",
                    title: "Admin Access Required",
                    message: "Only household administrators can access these settings."
                )
            }
        }
    }
    
    private var noHouseholdView: some View {
        EmptyStateView(
            icon: "house.slash",
            title: "No Household",
            message: "You need to be part of a household to manage members."
        )
    }
    
    private var memberActionSheet: ActionSheet {
        guard let member = selectedMember else {
            return ActionSheet(title: Text("Member Actions"))
        }
        
        let isCurrentUser = member == authManager.currentUser
        
        var buttons: [ActionSheet.Button] = []
        
        if !isCurrentUser && isCurrentUserAdmin {
            buttons.append(.default(Text("View Profile")) {
                // Navigate to member profile
            })
            
            buttons.append(.default(Text("Change Role")) {
                // Show role change dialog
            })
            
            buttons.append(.destructive(Text("Remove from Household")) {
                removeMember(member)
            })
        }
        
        buttons.append(.cancel())
        
        return ActionSheet(
            title: Text(member.name ?? "Unknown Member"),
            message: Text("Choose an action"),
            buttons: buttons
        )
    }
    
    // MARK: - Actions
    
    private func shareInviteCode(_ code: String) {
        let activityVC = UIActivityViewController(
            activityItems: ["Join my household! Use invite code: \(code)"],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func copyInviteCode(_ code: String) {
        UIPasteboard.general.string = code
        
        PremiumAudioHapticSystem.playSuccess()
        
        // Show success message (you might want to add a toast notification here)
    }
    
    private func regenerateInviteCode() {
        // This would call the backend to generate a new invite code
        // For now, we'll just show that the action was triggered
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            // In real implementation, this would update the household invite code
        }
    }
    
    private func removeMember(_ member: User) {
        guard let household = currentHousehold else { return }
        
        isLoading = true
        
        // Find and remove the membership
        if let memberships = household.memberships?.allObjects as? [UserHouseholdMembership],
           let membershipToRemove = memberships.first(where: { $0.user == member }) {
            
            viewContext.delete(membershipToRemove)
            
            do {
                try viewContext.save()
                
                // Sync removal with backend
                syncService.syncMemberRemoval(userId: member.id?.uuidString ?? "", householdId: household.id?.uuidString ?? "")
                
                LoggingManager.shared.info("Member removed from household: \(member.name ?? "Unknown")", category: "Members")
                
            } catch {
                LoggingManager.shared.error("Failed to remove member: \(error.localizedDescription)", category: "Members")
                errorMessage = "Failed to remove member"
            }
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Views

struct EnhancedMemberRowView: View {
    let member: User
    let currentUser: User?
    let isAdmin: Bool
    let onMemberTapped: (User) -> Void
    
    private var isCurrentUser: Bool {
        member == currentUser
    }
    
    private var memberRole: String {
        // This should come from the membership relationship
        // For now, we'll use a placeholder
        isCurrentUser ? "You" : "Member"
    }
    
    var body: some View {
        Button(action: { 
            PremiumAudioHapticSystem.playButtonTap(style: .light)
            onMemberTapped(member) 
        }) {
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(Color(member.avatarColor ?? "blue"))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(member.name?.prefix(1) ?? "?"))
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(isCurrentUser ? Color.blue : Color.clear, lineWidth: 3)
                    )
                
                // Member Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name ?? "Unknown Member")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isCurrentUser {
                            Text("(You)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        
                        Text("\(member.points) points")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(memberRole)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if let joinDate = member.createdAt {
                        Text("Joined \(formatDate(joinDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status Indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PremiumPressButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(member.name ?? "Unknown Member"))
        .accessibilityHint(Text(isCurrentUser ? "You. Double-tap for actions." : "Opens actions for this member"))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct StatisticView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                        )
                )
    }
}

struct InviteCodeCardView: View {
    let household: Household
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Household Invite Code")
                .font(.headline.weight(.semibold))
            
            Text(household.inviteCode ?? "ERROR")
                .font(.largeTitle.weight(.bold).monospaced())
                .foregroundColor(.blue)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            
            Text("Share this code with friends and family to invite them to your household")
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
                        .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct ShareButton: View {
    let title: String
    let icon: String
    var style: ShareButtonStyle = .primary
    let action: () -> Void
    
    enum ShareButtonStyle {
        case primary, secondary
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .blue.opacity(0.1)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .blue
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(12)
        }
    }
}

struct AdminSection: View {
    let title: String
    let items: [AdminItem]
    
    var body: some View {
        Section(title) {
            ForEach(items, id: \.title) { item in
                Button(action: {
                    PremiumAudioHapticSystem.playButtonTap(style: .light)
                    item.action()
                }) {
                    HStack {
                        Image(systemName: item.icon)
                            .foregroundColor(item.color)
                            .frame(width: 24)
                        
                        Text(item.title)
                            .foregroundColor(item.color)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PremiumPressButtonStyle())
            }
        }
    }
}

struct AdminItem {
    let title: String
    let icon: String
    var color: Color = .primary
    let action: () -> Void
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Processing...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}

// MARK: - Sheet Views

struct InviteMemberSheet: View {
    let household: Household?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Invite functionality would be implemented here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Invite Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct CreateInviteSheet: View {
    let household: Household?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Create invite link functionality would be implemented here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Create Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Extension for HouseholdSyncService

extension HouseholdSyncService {
    func syncMemberRemoval(userId: String, householdId: String) {
        // Emit member removal event
        emit("memberRemoved", data: [
            "userId": userId,
            "householdId": householdId,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
}

// MARK: - Preview

struct EnhancedMemberManagementView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedMemberManagementView()
            .environmentObject(IntegratedAuthenticationManager.shared)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
