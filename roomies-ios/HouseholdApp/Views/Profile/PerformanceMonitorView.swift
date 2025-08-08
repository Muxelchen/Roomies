import SwiftUI

struct PerformanceMonitorView: View {
    @EnvironmentObject private var performanceManager: PerformanceManager
    @AppStorage("performanceMonitoringEnabled") private var performanceMonitoringEnabled = false
    
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: .dashboard, style: .minimal)
            VStack(alignment: .leading, spacing: PremiumDesignSystem.Spacing.small.value) {
                Text("Performance Monitoring")
                    .premiumText(.sectionHeader)
                    .accessibilityHeader()
                    .padding(.horizontal)

                VStack(spacing: PremiumDesignSystem.Spacing.small.value) {
                    HStack {
                        Text("Enable Monitoring")
                        Spacer()
                        Toggle("", isOn: $performanceMonitoringEnabled)
                            .labelsHidden()
                            .toggleStyle(PremiumToggleStyle(tint: PremiumDesignSystem.SectionColor.dashboard.primary))
                            .accessibilityLabel(Text("Enable Monitoring"))
                    }
                    .padding(.horizontal)

                    if performanceMonitoringEnabled {
                        PremiumCard(sectionColor: .dashboard) {
                            VStack(spacing: PremiumDesignSystem.Spacing.micro.value) {
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
                                HStack {
                                    Spacer()
                                    PremiumButton("Run Cleanup", icon: "wand.and.stars", sectionColor: .dashboard) {
                                        performanceManager.scheduleBackgroundCleanup()
                                    }
                                    .disabled(performanceManager.isOptimizing)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
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