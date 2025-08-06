import SwiftUI

// MARK: - Super Lazy Store View
// This view shows a placeholder and only loads the actual store when user taps
struct SuperLazyStoreView: View {
    @State private var shouldLoadStore = false
    @State private var isStoreLoaded = false
    
    var body: some View {
        Group {
            if isStoreLoaded {
                StoreView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                // Beautiful store landing page
                storePreviewContent
            }
        }
    }
    
    private var storePreviewContent: some View {
        ZStack {
            // Beautiful gradient background
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    Color.purple.opacity(0.1),
                    Color.blue.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    Spacer(minLength: 50)
                    
                    // Store header
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: .purple.opacity(0.4), radius: 30, x: 0, y: 15)
                            
                            Image(systemName: "bag.fill")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            Text("Reward Store")
                                .font(.system(.largeTitle, design: .rounded, weight: .black))
                                .foregroundColor(.primary)
                            
                            Text("Redeem your points for amazing rewards!")
                                .font(.system(.title2, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Preview cards (fake store items)
                    VStack(spacing: 16) {
                        storePreviewCard(
                            icon: "gift.fill",
                            title: "Special Treats",
                            description: "Ice cream, candy, and more",
                            points: "50-100 pts",
                            color: .orange
                        )
                        
                        storePreviewCard(
                            icon: "gamecontroller.fill",
                            title: "Extra Game Time",
                            description: "1 hour of bonus screen time",
                            points: "75 pts",
                            color: .green
                        )
                        
                        storePreviewCard(
                            icon: "popcorn.fill",
                            title: "Movie Night Choice",
                            description: "Pick the family movie",
                            points: "100 pts",
                            color: .red
                        )
                    }
                    .padding(.horizontal)
                    
                    // Load store button
                    Button(action: {
                        loadStoreWithDelay()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "bag.badge.plus")
                                .font(.title2)
                            Text("Open Store")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: .purple.opacity(0.3), radius: 15, x: 0, y: 8)
                    }
                    .scaleEffect(shouldLoadStore ? 0.95 : 1.0)
                    .disabled(shouldLoadStore)
                    
                    if shouldLoadStore {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            Text("Loading Store...")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .transition(.opacity)
                    }
                    
                    Spacer(minLength: 50)
                }
            }
        }
    }
    
    private func storePreviewCard(icon: String, title: String, description: String, points: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text(description)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(points)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func loadStoreWithDelay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            shouldLoadStore = true
        }
        
        // Load the actual store with maximum delay to prevent freezing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            DispatchQueue.global(qos: .userInitiated).async {
                // Simulate any heavy work here
                Thread.sleep(forTimeInterval: 0.1)
                
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        isStoreLoaded = true
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct SuperLazyStoreView_Previews: PreviewProvider {
    static var previews: some View {
        SuperLazyStoreView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(GameificationManager.shared)
            .environmentObject(LocalizationManager.shared)
    }
}
