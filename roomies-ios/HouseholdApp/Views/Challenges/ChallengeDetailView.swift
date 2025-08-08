import SwiftUI
import CoreData

struct ChallengeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let challenge: Challenge

    var daysRemaining: Int {
        guard let dueDate = challenge.dueDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0)
    }

    var body: some View {
        NavigationView {
            ZStack {
                PremiumScreenBackground(sectionColor: .challenges, style: .minimal)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 56, height: 56)
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(challenge.title ?? "Unknown Challenge")
                                .font(.title2.bold())
                            if let desc = challenge.challengeDescription, !desc.isEmpty {
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Label("\(challenge.pointReward) pts", systemImage: "star.fill")
                            .foregroundColor(.yellow)
                        if daysRemaining > 0 { Label("\(daysRemaining)d left", systemImage: "clock") }
                        Spacer()
                    }
                    .font(.subheadline)

                    Spacer()

                    Button {
                        PremiumAudioHapticSystem.playButtonTap(style: .medium)
                        joinChallenge()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                            Text("Join Challenge")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(PremiumPressButtonStyle())
                }
                .padding(20)
            }
            .navigationTitle("Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        PremiumAudioHapticSystem.playModalDismiss()
                        dismiss()
                    }
                }
            }
        }
    }

    private func joinChallenge() {
        Task {
            if let challengeId = challenge.id?.uuidString {
                do {
                    _ = try await NetworkManager.shared.joinChallenge(challengeId: challengeId)
                } catch {
                    await MainActor.run {
                        if let currentUser = IntegratedAuthenticationManager.shared.currentUser,
                           let context = challenge.managedObjectContext {
                            let participants = (challenge.participants as? Set<User>) ?? []
                            if !participants.contains(currentUser) {
                                let mutable = NSMutableSet(set: challenge.participants ?? NSSet())
                                mutable.add(currentUser)
                                challenge.participants = mutable
                                try? context.save()
                            }
                        }
                    }
                }
            }
            PremiumAudioHapticSystem.playSuccess()
            dismiss()
        }
    }
}


