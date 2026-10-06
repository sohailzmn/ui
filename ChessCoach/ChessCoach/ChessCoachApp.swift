import SwiftUI
import UIKit

@main
struct ChessCoachApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Coach", systemImage: "sparkles") }

            GamesView()
                .tabItem { Label("Partien", systemImage: "square.grid.2x2.fill") }

            LearnView()
                .tabItem { Label("Lernen", systemImage: "brain.head.profile.fill") }

            SettingsView()
                .tabItem { Label("Setup", systemImage: "slider.horizontal.3") }
        }
        .tint(Color.coachMint)
    }
}

extension Color {
    static let coachBackground = Color(red: 0.058, green: 0.060, blue: 0.066)
    static let coachPanel = Color(red: 0.100, green: 0.103, blue: 0.112)
    static let coachPanel2 = Color(red: 0.130, green: 0.133, blue: 0.142)
    static let coachMint = Color(red: 1.0, green: 0.72, blue: 0.11)
    static let coachCyan = Color(red: 0.30, green: 0.80, blue: 0.74)
    static let coachPurple = Color(red: 0.56, green: 0.52, blue: 0.72)
    static let coachOrange = Color(red: 1.0, green: 0.60, blue: 0.18)
    static let coachRed = Color(red: 0.96, green: 0.30, blue: 0.33)
}

extension ReviewGrade {
    var tint: Color {
        switch self {
        case .brilliant: return Color(red: 0.20, green: 0.83, blue: 0.86)
        case .great: return Color(red: 0.37, green: 0.73, blue: 0.98)
        case .best: return Color.coachMint
        case .excellent: return Color(red: 0.55, green: 0.86, blue: 0.42)
        case .good: return Color(red: 0.64, green: 0.73, blue: 0.48)
        case .book: return Color(red: 0.66, green: 0.51, blue: 1.0)
        case .inaccuracy: return Color.coachOrange
        case .mistake: return Color(red: 1.0, green: 0.48, blue: 0.25)
        case .miss: return Color(red: 0.95, green: 0.39, blue: 0.64)
        case .blunder: return Color.coachRed
        }
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct GlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

struct PrimaryButtonLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(Color.black.opacity(0.86))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Color.coachMint,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 8, y: 4)
    }
}

struct ScreenBackground: View {
    var body: some View {
        ZStack {
            Color.coachBackground
            LinearGradient(
                colors: [Color.black.opacity(0.10), Color.coachBackground],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct AnimatedKnightHero: View {
    @State private var floating = false
    @State private var glowing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.coachMint.opacity(0.30), Color.coachCyan.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 128
                    )
                )
                .frame(width: 238, height: 238)
                .scaleEffect(glowing ? 1.07 : 0.92)

            Image("Coach")
                .resizable()
                .scaledToFit()
                .frame(width: 170, height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 45, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 45, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.coachMint.opacity(0.22), radius: 24, y: 12)
                .offset(y: floating ? -7 : 5)
                .rotationEffect(.degrees(floating ? 2.2 : -2.2))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                floating = true
            }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}

extension View {
    func coachPanel() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.coachPanel.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.065), lineWidth: 1)
                    )
            )
    }
}
