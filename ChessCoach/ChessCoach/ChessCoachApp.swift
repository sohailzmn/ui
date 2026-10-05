import SwiftUI

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
    static let coachBackground = Color(red: 0.035, green: 0.043, blue: 0.060)
    static let coachPanel = Color(red: 0.075, green: 0.088, blue: 0.115)
    static let coachPanel2 = Color(red: 0.105, green: 0.122, blue: 0.155)
    static let coachMint = Color(red: 0.36, green: 0.94, blue: 0.70)
    static let coachCyan = Color(red: 0.32, green: 0.73, blue: 0.98)
    static let coachPurple = Color(red: 0.66, green: 0.51, blue: 1.0)
    static let coachOrange = Color(red: 1.0, green: 0.68, blue: 0.30)
    static let coachRed = Color(red: 1.0, green: 0.36, blue: 0.42)
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
                LinearGradient(
                    colors: [Color.coachMint, Color(red: 0.56, green: 1.0, blue: 0.82)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: Color.coachMint.opacity(0.2), radius: 20, y: 8)
    }
}

struct ScreenBackground: View {
    var body: some View {
        ZStack {
            Color.coachBackground
            RadialGradient(
                colors: [Color.coachPurple.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 470
            )
            RadialGradient(
                colors: [Color.coachMint.opacity(0.09), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 420
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
                        colors: [Color.coachMint.opacity(0.36), Color.coachCyan.opacity(0.1), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 125
                    )
                )
                .frame(width: 230, height: 230)
                .scaleEffect(glowing ? 1.08 : 0.92)

            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
                .frame(width: 154, height: 154)
                .rotationEffect(.degrees(floating ? 4 : -4))

            Text("♞")
                .font(.system(size: 106, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, Color.coachMint], startPoint: .top, endPoint: .bottom)
                )
                .offset(y: floating ? -7 : 5)
                .shadow(color: Color.coachMint.opacity(0.25), radius: 18, y: 12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                floating = true
            }
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}

extension View {
    func coachPanel() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.coachPanel.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.065), lineWidth: 1)
                    )
            )
    }
}
