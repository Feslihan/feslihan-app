import SwiftUI

struct SplashView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var subscriptions: SubscriptionService
    @State private var iconScale: CGFloat = 0.75
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var finished = false

    /// Keep the splash up long enough for the intro animation to play, even
    /// when auth/subscription load finishes instantly.
    private let minimumDisplay: TimeInterval = 0.9
    /// Fallback so a slow network can never hang the splash indefinitely.
    private let readinessTimeout: TimeInterval = 4.0

    var body: some View {
        if finished {
            if hasCompletedOnboarding {
                ModeSelectionView()
                    .transition(.opacity)
            } else {
                OnboardingView(onComplete: { hasCompletedOnboarding = true })
                    .transition(.opacity)
            }
        } else {
            ZStack {
                DS.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 22) {
                        // Leaf icon in circle
                        ZStack {
                            Circle()
                                .fill(DS.emberLight)
                                .frame(width: 96, height: 96)

                            Image(systemName: "leaf.fill")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundStyle(DS.ember)
                        }
                        .scaleEffect(iconScale)

                        Text("Feslihan")
                            .font(.system(size: 40, weight: .semibold, design: .serif))
                            .foregroundStyle(DS.ink)
                            .opacity(titleOpacity)

                        Text("Anne, ne yesek?")
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(DS.smoke)
                            .opacity(subtitleOpacity)
                    }

                    Spacer()

                    // Loading spinner
                    ProgressView()
                        .tint(DS.ember)
                        .padding(.bottom, 60)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    iconScale = 1.0
                }
                withAnimation(.easeOut(duration: 0.3).delay(0.4)) {
                    titleOpacity = 1.0
                }
                withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
                    subtitleOpacity = 1.0
                }
            }
            .task {
                // Drive the transition off actual auth/subscription readiness,
                // with a timeout fallback, instead of a fixed delay.
                let start = Date()
                while !subscriptions.isReady,
                      Date().timeIntervalSince(start) < readinessTimeout {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }

                let elapsed = Date().timeIntervalSince(start)
                if elapsed < minimumDisplay {
                    try? await Task.sleep(
                        nanoseconds: UInt64((minimumDisplay - elapsed) * 1_000_000_000)
                    )
                }

                withAnimation(.easeOut(duration: 0.2)) {
                    finished = true
                }
            }
        }
    }
}
