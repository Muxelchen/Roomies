import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var onboardingPages: [OnboardingPage] {
        [
            OnboardingPage(
                title: localizationManager.localizedString("onboarding.welcome.title"),
                description: localizationManager.localizedString("onboarding.welcome.description"),
                imageName: "house.fill",
                color: .blue
            ),
            OnboardingPage(
                title: localizationManager.localizedString("onboarding.tasks.title"),
                description: localizationManager.localizedString("onboarding.tasks.description"),
                imageName: "gift.fill",
                color: .green
            ),
            OnboardingPage(
                title: localizationManager.localizedString("onboarding.challenges.title"),
                description: localizationManager.localizedString("onboarding.challenges.description"),
                imageName: "trophy.fill",
                color: .orange
            )
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    OnboardingPageView(page: onboardingPages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .animation(.easeInOut, value: currentPage)
            
            // Action Buttons
            VStack(spacing: 16) {
                if currentPage == onboardingPages.count - 1 {
                    Button(action: completeOnboarding) {
                        Text(localizationManager.localizedString("onboarding.get_started"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.blue)
                            .cornerRadius(25)
                    }
                } else {
                    Button(action: nextPage) {
                        Text(localizationManager.localizedString("onboarding.next"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.blue)
                            .cornerRadius(25)
                    }
                }
                
                Button(action: completeOnboarding) {
                    Text(localizationManager.localizedString("onboarding.skip"))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private func nextPage() {
        withAnimation {
            currentPage += 1
        }
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: page.imageName)
                .font(.system(size: 100))
                .foregroundColor(page.color)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}