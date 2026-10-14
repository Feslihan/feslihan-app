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

                    VStack(spacing: 0) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(DS.ember)
                            .scaleEffect(iconScale)

                        Text("Feslihan")
                            .font(.system(size: 46, weight: .semibold, design: .serif))
                            .foregroundStyle(DS.ink)
                            .opacity(titleOpacity)
                            .padding(.top, 18)

                        Text("Anne, ne yesek?")
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(DS.smoke)
                            .opacity(subtitleOpacity)
                            .padding(.top, 10)
                    }
                    .padding(.top, -30)

                    Spacer()

                    // Minimal line loader
                    SplashLineLoader()
                        .padding(.bottom, 64)
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

/// Thin editorial progress line: a short ink segment sweeping a hairline track.
struct SplashLineLoader: View {
    @State private var sweep = false

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(DS.stone)
            Rectangle()
                .fill(DS.ink)
                .frame(width: 16, height: 2)
                .offset(x: sweep ? 24 : 0)
        }
        .frame(width: 40, height: 2)
        .clipped()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                sweep = true
            }
        }
    }
}
