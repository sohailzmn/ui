import SwiftUI

/// Independent dark-mode home dashboard; every statistic is sourced from
/// local reviews / practice, never synthetic values or a paid app's backend.
struct InspiredHomeView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var journal = DrillJournal.shared
    @State private var showConnect = false

    private var blunders: [TrainingPuzzle] {
        store.puzzles.filter { $0.grade == .blunder || $0.grade == .miss }
    }
    private var dueBlunders: [TrainingPuzzle] {
        let due = journal.due(blunders)
        return due.isEmpty ? blunders : due
    }
    private var duePuzzles: [TrainingPuzzle] {
        journal.due(store.puzzles)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.coachBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        playerHeader
                        welcomeHeader
                        focusCard
                        trainingGrid
                        courseSection
                        todaysAction
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .refreshable {
                    await store.sync()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showConnect) {
                ConnectView()
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
            }
            .coachErrorAlert(store: store)
        }
    }

    private var playerHeader: some View {
        HStack(spacing: 10) {
            Image("AcademyHome")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.username.isEmpty ? "ChessCoach" : store.username)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(store.profile?.rating.map { "Chess.com · \($0) Elo" } ?? "Schach besser verstehen")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color.coachMint)
                Text("\(journal.completed)")
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .font(.subheadline.bold())
            .padding(9)
            .background(Color.coachPanel2, in: Capsule())
            Button { showConnect = true } label: {
                Image(systemName: store.username.isEmpty ? "person.crop.circle.badge.plus" : "person.crop.circle")
                    .font(.system(size: 23))
                    .foregroundStyle(Color.coachMint)
            }
            .accessibilityLabel(store.username.isEmpty ? "Chess.com verbinden" : "Konto verwalten")
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("DEIN TRAINING")
                    .font(.caption2.bold())
                    .tracking(2)
                    .foregroundStyle(Color.coachMint)
                Spacer()
                Text(Date(), format: .dateTime.day().month(.abbreviated))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.46))
            }
            Text("Heute ein bisschen\nbesser spielen.")
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(store.username.isEmpty
                 ? "Verbinde deinen Chess.com-Namen, um aus deinen eigenen Partien zu lernen."
                 : "\(store.reviewedGamesCount) analysierte Partien · \(store.puzzles.count) Trainingspositionen")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.63))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("DEIN FOKUS", systemImage: "scope")
                    .font(.caption.bold())
                    .foregroundStyle(Color.coachMint)
                Spacer()
                Text("\(duePuzzles.count) offen")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            HStack(spacing: 14) {
                Image("AcademyBlunder")
                    .resizable().scaledToFit()
                    .frame(width: 69, height: 69)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Blunder Training")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Verlorene Vorteile erkennen und korrigieren")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.61))
                }
                Spacer(minLength: 0)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule().fill(Color.coachMint)
                        .frame(width: g.size.width * (store.puzzles.isEmpty ? 0 : Double(journal.completed) / Double(store.puzzles.count)).clamped(to: 0...1))
                }
            }
            .frame(height: 7)

            if !dueBlunders.isEmpty {
                NavigationLink {
                    GuidedBlunderSession(puzzles: dueBlunders, woodpecker: false)
                } label: { actionLabel("Training starten", "arrow.right") }
                .buttonStyle(PressScaleButtonStyle())
            } else {
                Button { showConnect = true } label: {
                    actionLabel("Chess.com verbinden", "person.crop.circle.badge.plus")
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .padding(16)
        .background(Color.coachPanel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func actionLabel(_ label: String, _ icon: String) -> some View {
        HStack {
            Text(label).font(.subheadline.bold())
            Spacer()
            Image(systemName: icon).font(.subheadline.bold())
        }
        .foregroundStyle(Color.black.opacity(0.88))
        .padding(.vertical, 13)
        .padding(.horizontal, 15)
        .background(Color.coachMint, in: RoundedRectangle(cornerRadius: 12))
    }

    private var trainingGrid: some View {
        HStack(spacing: 10) {
            NavigationLink {
                GuidedBlunderSession(puzzles: duePuzzles.isEmpty ? store.puzzles : duePuzzles, woodpecker: false)
            } label: {
                trainingTile(asset: "AcademyPuzzle", title: "Daily Puzzle", subtitle: "\(duePuzzles.count) fällig")
            }
            .disabled(store.puzzles.isEmpty)

            NavigationLink {
                GuidedBlunderSession(puzzles: store.puzzles, woodpecker: true)
            } label: {
                trainingTile(asset: "AcademyWoodpecker", title: "Woodpecker", subtitle: "\(store.puzzles.count) Positionen")
            }
            .disabled(store.puzzles.isEmpty)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func trainingTile(asset: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(asset).resizable().scaledToFit().frame(width: 48, height: 48)
            Text(title).font(.subheadline.bold()).foregroundStyle(.white)
            Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Color.coachPanel, in: RoundedRectangle(cornerRadius: 17))
        .opacity(store.puzzles.isEmpty ? 0.56 : 1)
    }

    private var courseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dein Fortschritt").font(.headline).foregroundStyle(.white)
            HStack(spacing: 9) {
                progressTile(icon: "AcademyProgress",
                             value: store.averageAccuracy.map { "\(Int($0)) %" } ?? "–",
                             title: "Genauigkeit")
                progressTile(icon: "AcademyCoach",
                             value: "\(journal.successfulAttempts)",
                             title: "Gelöst")
                progressTile(icon: "AcademyHome",
                             value: "\(store.reviewedGamesCount)",
                             title: "Reviews")
            }
        }
    }

    private func progressTile(icon: String, value: String, title: String) -> some View {
        VStack(spacing: 7) {
            Image(icon).resizable().scaledToFit().frame(width: 40, height: 40)
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.56))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Color.coachPanel, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private var todaysAction: some View {
        if store.username.isEmpty {
            Button { showConnect = true } label: { actionLabel("Mit deinen Partien beginnen", "arrow.right") }
                .buttonStyle(PressScaleButtonStyle())
        } else if !store.puzzles.isEmpty {
            NavigationLink {
                GuidedBlunderSession(puzzles: dueBlunders.isEmpty ? store.puzzles : dueBlunders,
                                     woodpecker: false)
            } label: { actionLabel("Training fortsetzen", "arrow.right") }
                .buttonStyle(PressScaleButtonStyle())
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Deine Übungen entstehen aus Reviews").font(.headline)
                Text("Öffne Games und analysiere eine Partie mit Stockfish.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.coachPanel, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private extension Double {
    func clamped(to bounds: ClosedRange<Double>) -> Double {
        min(max(self, bounds.lowerBound), bounds.upperBound)
    }
}
