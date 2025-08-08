import SwiftUI

struct AllBadgesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.managedObjectContext) private var viewContext
    
    private let categories: [BadgeCategory] = BadgeCategory.allCases
    private let provider: BadgesProviding = LocalBadgesProvider()
    
    private var data: [BadgeCategory: [BadgeItem]] {
        provider.fetchAllBadges(context: viewContext)
    }
    
    var body: some View {
        ZStack {
            PremiumScreenBackground(sectionColor: .profile, style: .minimal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(categories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            // Category Header
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [categoryColor(category), categoryColor(category).opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                        .shadow(color: categoryColor(category).opacity(0.3), radius: 8, x: 0, y: 4)
                                    
                                    Image(systemName: categoryIcon(category))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                Text(category.rawValue)
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            // Badges grid
                            let items = data[category] ?? []
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(Array(items.enumerated()), id: \.offset) { index, badge in
                                    AllBadgesBadgeCell(
                                        iconName: badge.icon,
                                        name: badge.name,
                                        color: badge.color.opacity(badge.earned ? 1.0 : 0.4),
                                        animationDelay: Double(index) * 0.06
                                    )
                                    .overlay(
                                        VStack {
                                            if !badge.earned {
                                                Text(badge.requirement)
                                                    .font(.system(.caption2, design: .rounded, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                    .multilineTextAlignment(.center)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                colors: [categoryColor(category).opacity(0.6), categoryColor(category).opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .shadow(color: categoryColor(category).opacity(0.3), radius: 20, x: 0, y: 8)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("All Badges")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    PremiumAudioHapticSystem.playModalDismiss()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                }
                .buttonStyle(PremiumPressButtonStyle())
            }
        }
    }
    
    private func categoryColor(_ category: BadgeCategory) -> Color {
        switch category {
        case .points: return .yellow
        case .tasks: return .green
        case .streak: return .orange
        case .challenges: return .purple
        case .special: return .blue
        }
    }
    
    private func categoryIcon(_ category: BadgeCategory) -> String {
        switch category {
        case .points: return "star.fill"
        case .tasks: return "checkmark.seal.fill"
        case .streak: return "flame.fill"
        case .challenges: return "trophy.fill"
        case .special: return "rosette"
        }
    }
}

struct AllBadgesBadgeCell: View {
    let iconName: String
    let name: String
    let color: Color
    let animationDelay: Double
    
    @State private var scale: CGFloat = 0.9
    @State private var isPressed = false
    @State private var glow: Double = 0.3
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(glow))
                        .frame(width: 64, height: 64)
                        .blur(radius: 6)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color, color.opacity(0.7)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 25
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.4), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                }
                .scaleEffect(scale)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                
                Text(name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 80)
            }
            .padding(8)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(animationDelay)) {
                scale = 1.0
            }
            withAnimation(.easeInOut(duration: 2.0).delay(animationDelay + 0.8)) {
                glow = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0 + animationDelay) {
                withAnimation(.easeInOut(duration: 2.0)) {
                    glow = 0.3
                }
            }
        }
    }
}

struct AllBadgesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AllBadgesView()
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

