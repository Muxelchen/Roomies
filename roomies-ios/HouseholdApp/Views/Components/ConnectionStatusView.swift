import SwiftUI
import Combine

/// Displays real-time connection status for network and socket connections
struct ConnectionStatusView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var socketManager = SocketManager.shared
    @State private var showDetails = false
    @State private var animateIcon = false
    
    private var overallStatus: ConnectionStatus {
        if !networkManager.isOnline {
            return .offline
        } else if socketManager.isConnected {
            return .connected
        } else if socketManager.connectionStatus == .connecting || 
                  socketManager.connectionStatus == .reconnecting {
            return .connecting
        } else {
            return .disconnected
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Status Icon
            Image(systemName: overallStatus.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(overallStatus.color))
                .scaleEffect(animateIcon ? 1.2 : 1.0)
.animation(
                    overallStatus == .connecting ? 
                    .easeInOut(duration: 0.5) :
                    .default,
                    value: animateIcon
                )
            
            // Status Text
            Text(overallStatus.displayText)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(Color(overallStatus.color))
            
            // Sync Indicator
            if let lastSync = IntegratedTaskManager.shared.lastSyncDate {
                Text("• Synced \(lastSync.timeAgoDisplay())")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            Color(overallStatus.color).opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color(overallStatus.color).opacity(0.2), radius: 8, x: 0, y: 4)
        .onTapGesture {
            PremiumAudioHapticSystem.playButtonTap(style: .light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showDetails.toggle()
            }
        }
        .sheet(isPresented: $showDetails) {
            ConnectionDetailsView()
        }
        .onAppear {
if overallStatus == .connecting {
                // Single pulse on appear; further pulses triggered by status changes
                animateIcon = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    animateIcon = false
                }
            }
        }
        .onChange(of: overallStatus) { newStatus in
if newStatus == .connecting {
                animateIcon = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    animateIcon = false
                }
            } else {
                animateIcon = false
            }
        }
    }
}

/// Detailed connection information sheet
struct ConnectionDetailsView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var socketManager = SocketManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Network Status Card
                    StatusCard(
                        title: "Network Connection",
                        icon: "wifi",
                        status: networkManager.isOnline ? "Connected" : "Offline",
                        color: networkManager.isOnline ? "green" : "red",
                        details: [
                            ("API URL", AppConfig.apiBaseURL),
                            ("Environment", AppConfig.Environment.current.rawValue.capitalized),
                            ("Status", networkManager.isOnline ? "Online" : "Offline")
                        ]
                    )
                    
                    // Socket Status Card
                    StatusCard(
                        title: "Real-time Updates",
                        icon: "bolt.fill",
                        status: socketManager.connectionStatus.displayText,
                        color: socketManager.connectionStatus.color,
                        details: [
                            ("Socket URL", AppConfig.socketURL),
                            ("Status", socketManager.connectionStatus.displayText),
                            ("Last Ping", socketManager.lastPingTime?.formatted() ?? "Never")
                        ]
                    )
                    
                    // Sync Status Card
                    if let lastSync = IntegratedTaskManager.shared.lastSyncDate {
                        StatusCard(
                            title: "Data Sync",
                            icon: "arrow.triangle.2.circlepath",
                            status: "Last synced \(lastSync.timeAgoDisplay())",
                            color: "blue",
                            details: [
                                ("Last Sync", lastSync.formatted()),
                                ("Tasks", "\(IntegratedTaskManager.shared.tasks.count) loaded"),
                                ("Auto-sync", "Every 60 seconds")
                            ]
                        )
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            PremiumAudioHapticSystem.playButtonTap(style: .medium)
                            Task {
                                await IntegratedTaskManager.shared.syncTasks()
                            }
                        }) {
                            Label("Force Sync", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        if socketManager.isConnected {
                            Button(action: {
                                PremiumAudioHapticSystem.playButtonTap(style: .light)
                                socketManager.disconnect()
                            }) {
                                Label("Disconnect Socket", systemImage: "xmark.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(12)
                            }
                        } else {
                            Button(action: {
                                PremiumAudioHapticSystem.playButtonTap(style: .light)
                                socketManager.connect()
                            }) {
                                Label("Connect Socket", systemImage: "bolt.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Connection Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Reusable status card component
struct StatusCard: View {
    let title: String
    let icon: String
    let status: String
    let color: String
    let details: [(String, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Color(color))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    Text(status)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(Color(color))
                }
                
                Spacer()
                
                Circle()
                    .fill(Color(color))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .fill(Color(color).opacity(0.3))
                            .frame(width: 20, height: 20)
                            .scaleEffect(1.5)
                            .opacity(0.5)
                            .animation(
                                .easeInOut(duration: 1.2),
                                value: status
                            )
                    )
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(details, id: \.0) { label, value in
                    HStack {
                        Text(label)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(value)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(color).opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Connection Status Enum
enum ConnectionStatus {
    case offline
    case disconnected
    case connecting
    case connected
    
    var displayText: String {
        switch self {
        case .offline: return "Offline"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        }
    }
    
    var color: String {
        switch self {
        case .offline: return "gray"
        case .disconnected: return "red"
        case .connecting: return "yellow"
        case .connected: return "green"
        }
    }
    
    var icon: String {
        switch self {
        case .offline: return "wifi.slash"
        case .disconnected: return "exclamationmark.circle.fill"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .connected: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Date Extension
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview
struct ConnectionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ConnectionStatusView()
            
            ConnectionDetailsView()
        }
        .padding()
    }
}
