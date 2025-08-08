import SwiftUI

struct PerformanceMonitorView: View {
    @EnvironmentObject private var performanceManager: PerformanceManager
    @AppStorage("performanceMonitoringEnabled") private var performanceMonitoringEnabled = false
    
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: .dashboard, style: .minimal)
            Section("Performance Monitoring") {
            Toggle("Performance Monitoring", isOn: $performanceMonitoringEnabled)
            
            if performanceMonitoringEnabled {
                HStack {
                    Text("App Launch Time")
                    Spacer()
                    Text("\(String(format: "%.2f", performanceManager.appLaunchTime))s")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Memory Usage")
                    Spacer()
                    Text("\(performanceManager.memoryUsage / 1024 / 1024) MB")
                        .foregroundColor(.secondary)
                }
                
                if performanceManager.isOptimizing {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text("Optimizing...")
                            .foregroundColor(.orange)
                    }
                }
                
                Button("Run Cleanup") {
                    performanceManager.scheduleBackgroundCleanup()
                }
                .disabled(performanceManager.isOptimizing)
            }
            }
        }
    }
}

struct PerformanceMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceMonitorView()
            .environmentObject(PerformanceManager.shared)
    }
}