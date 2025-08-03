import SwiftUI

struct PerformanceMonitorView: View {
    @EnvironmentObject private var performanceManager: PerformanceManager
    @AppStorage("performanceMonitoringEnabled") private var performanceMonitoringEnabled = false
    
    var body: some View {
        Section("Performance-Überwachung") {
            Toggle("Performance-Monitoring", isOn: $performanceMonitoringEnabled)
                .onChange(of: performanceMonitoringEnabled) { newValue in
                    if newValue {
                        performanceManager.enableMonitoring()
                    } else {
                        performanceManager.disableMonitoring()
                    }
                }
            
            if performanceMonitoringEnabled {
                HStack {
                    Text("CPU-Nutzung")
                    Spacer()
                    Text("\(Int(performanceManager.cpuUsage))%")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Speicher-Nutzung")
                    Spacer()
                    Text("\(Int(performanceManager.memoryUsage))%")
                        .foregroundColor(.secondary)
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