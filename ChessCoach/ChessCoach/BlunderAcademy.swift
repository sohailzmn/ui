import SwiftUI

// The training module is based exclusively on the user's own reviewed games.
// It is original work and does not require a third-party premium subscription.
struct DrillRecord: Codable {
    var attempts: Int = 0
    var successes: Int = 0
    var streak: Int = 0
    var intervalDays: Int = 0
    var nextDue: Date = .distantPast
}

@MainActor
final class DrillJournal: ObservableObject {
    static let shared = DrillJournal()
    @Published private(set) var records: [String: DrillRecord] = [:]
    private let key = "chesscoach.videoEdition.drillJournal.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([String: DrillRecord].self, from: data) {
            records = saved
        }
    }

    func due(_ puzzles: [TrainingPuzzle]) -> [TrainingPuzzle] {
        let now = Date()
        return puzzles.filter { (records[$0.id]?.nextDue ?? .distantPast) <= now }
            .sorted {
                let first = records[$0.id]?.attempts ?? 0
                let second = records[$1.id]?.attempts ?? 0
                if first != second { return first < second }
                return $0.grade == .blunder && $1.grade != .blunder
            }
    }

    func record(for puzzle: TrainingPuzzle) -> DrillRecord {
        records[puzzle.id] ?? DrillRecord()
    }

    func finish(_ puzzle: TrainingPuzzle, solvedWithoutHelp: Bool) {
        var item = records[puzzle.id] ?? DrillRecord()
        item.attempts += 1
        if solvedWithoutHelp {
            item.successes += 1
            item.streak += 1
            let intervals = [0, 1, 3, 7, 14, 30, 60]
            item.intervalDays = intervals[min(item.streak, intervals.count - 1)]
            item.nextDue = item.intervalDays == 0
                ? Date().addingTimeInterval(3600)
                : Date().addingTimeInterval(TimeInterval(item.intervalDays * 86400))
        } else {
            item.streak = 0
            item.intervalDays = 0
            item.nextDue = Date().addingTimeInterval(1800)
        }
        records[puzzle.id] = item
        if let bytes = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(bytes, forKey: key)
        }
    }

    var completed: Int { records.values.filter { $0.attempts > 0 }.count }
    var successfulAttempts: Int { records.values.reduce(0) { $0 + $1.successes } }
    var totalAttempts: Int { records.values.reduce(0) { $0 + $1.attempts } }
}

private enum TrainingTrack: String, CaseIterable, Identifiable {
    case blunders = "Blunder"
    case all = "Alle Fehler"
    case woodpecker = "Woodpecker"
    var id: String { rawValue }
}

struct TrainingHubView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var journal = DrillJournal.shared
    @State private var track: TrainingTrack = .blunders

    private var allPuzzles: [TrainingPuzzle] { store.puzzles }
    private var blunders: [TrainingPuzzle] { allPuzzles.filter { $0.grade == .blunder || $0.grade == .miss } }
    private var dueBlunders: [TrainingPuzzle] { journal.due(blunders) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.coachBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 17) {
                        headline
                        progress
                        trackSelector
                        if store.puzzles.isEmpty {
                            emptyTraining
                        } else {
                            featured
                            if !blunders.isEmpty { blunderShield }
                            dailyList
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("TRAININGSZENTRUM", systemImage: "scope")
                    .font(.caption.bold())
                    .foregroundStyle(Color.coachMint)
                Spacer()
                Image(systemName: "bolt.shield.fill")
                    .foregroundStyle(Color.coachMint)
            }
            Text("Deine Fehler sind\ndein Vorteil.")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Trainiere die kritischen Momente aus deinen eigenen Partien. Alle Übungen sind in dieser App frei verfügbar.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.54))
        }
    }

    private var progress: some View {
        HStack(spacing: 10) {
            metric("\(allPuzzles.count)", "Positionen", "square.grid.3x3.fill", .white)
            metric("\(dueBlunders.count)", "Fällig", "clock.arrow.circlepath", Color.coachMint)
            metric("\(journal.completed)", "Geübt", "checkmark.circle.fill", Color.coachCyan)
        }
    }

    private func metric(_ value: String, _ name: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(color).font(.footnote)
            Text(value).font(.system(size: 24, weight: .black, design: .rounded)).monospacedDigit()
            Text(name).font(.caption2).foregroundStyle(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.coachPanel, in: RoundedRectangle(cornerRadius: 15))
    }

    private var trackSelector: some View {
        HStack(spacing: 7) {
            ForEach(TrainingTrack.allCases) { item in
                Button {
                    withAnimation(.snappy(duration: 0.20)) { track = item }
                } label: {
                    Text(item.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(track == item ? .black : .white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(track == item ? Color.coachMint : Color.coachPanel2,
                                    in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }

    @ViewBuilder private var featured: some View {
        switch track {
        case .blunders:
            trainingCard(title: "Blunder Training", subtitle: "Aus echten Patzern lernen",
                         caption: "\(blunders.count) kritische Positionen", icon: "exclamationmark.triangle.fill",
                         tint: Color.coachOrange,
                         candidates: dueBlunders.isEmpty ? blunders : dueBlunders, woodpecker: false)
        case .all:
            trainingCard(title: "Fehler korrigieren", subtitle: "Jeder verlorene Vorteil zählt",
                         caption: "\(allPuzzles.count) Positionen", icon: "target",
                         tint: Color.coachCyan,
                         candidates: journal.due(allPuzzles).isEmpty ? allPuzzles : journal.due(allPuzzles), woodpecker: false)
        case .woodpecker:
            trainingCard(title: "Woodpecker", subtitle: "Wiederholen. Erkennen. Beschleunigen.",
                         caption: "\(allPuzzles.count) Positionen pro Zyklus",
                         icon: "arrow.triangle.2.circlepath", tint: Color.coachMint,
                         candidates: allPuzzles, woodpecker: true)
        }
    }

    @ViewBuilder private var blunderShield: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("BLUNDER SHIELD", systemImage: "shield.lefthalf.filled")
                .font(.caption.bold())
                .foregroundStyle(Color.coachMint)
            Text("Erkenne deine gefährlichsten Fehler")
                .font(.headline)
            Text("Eine Aufgabe kommt nach Fehlern früher wieder. Richtig gelöste Positionen erscheinen in größeren Abständen.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.59))
            HStack {
                Text("\(journal.successfulAttempts) richtige Lösungen")
                Spacer()
                Text("\(journal.totalAttempts) Versuche")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.70))
        }
        .padding(16)
        .background(Color.coachPanel, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder private var dailyList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Deine nächsten Aufgaben").font(.headline)
            ForEach(Array(allPuzzles.prefix(5))) { puzzle in
                HStack(spacing: 10) {
                    Image(systemName: puzzle.grade.symbol)
                        .font(.title3)
                        .foregroundStyle(puzzle.grade.tint)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Gegen \(puzzle.opponent)").font(.subheadline.bold())
                        Text("Zug \((puzzle.ply + 1) / 2) · \(puzzle.grade.rawValue)")
                            .font(.caption).foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    if journal.record(for: puzzle).attempts > 0 {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.coachCyan)
                    } else {
                        Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(12)
                .background(Color.coachPanel, in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    private var emptyTraining: some View {
        VStack(spacing: 14) {
            Image(systemName: "chess.knight.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.coachMint)
            Text("Dein Blunder-Training wartet").font(.title3.bold())
            Text("Verbinde unter „Games“ deinen Chess.com-Namen und analysiere eine Partie mit Stockfish. Daraus entstehen echte Übungen, ohne Demo-Daten.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.coachPanel, in: RoundedRectangle(cornerRadius: 20))
    }

    private func trainingCard(title: String, subtitle: String, caption: String, icon: String,
                              tint: Color, candidates: [TrainingPuzzle], woodpecker: Bool) -> some View {
        NavigationLink {
            GuidedBlunderSession(puzzles: candidates, woodpecker: woodpecker)
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 35, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 68, height: 64)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))
                    Spacer()
                    Text("FREI")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.coachMint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.coachMint.opacity(0.12), in: Capsule())
                }
                Text(title).font(.title2.bold()).foregroundStyle(.white)
                Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.67))
                HStack {
                    Label(caption, systemImage: "square.grid.2x2")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                    Spacer()
                    Text("Training starten")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.coachMint, in: Capsule())
                }
            }
            .padding(19)
            .background(
                LinearGradient(colors: [Color.coachPanel2, tint.opacity(0.14)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(candidates.isEmpty)
    }
}

struct GuidedBlunderSession: View {
    let puzzles: [TrainingPuzzle]
    let woodpecker: Bool

    @Environment(\.dismiss) private var dismiss
    @StateObject private var journal = DrillJournal.shared
    @State private var index = 0
    @State private var selected: String?
    @State private var didMistake = false
    @State private var finishedPosition = false
    @State private var revealed = false
    @State private var message = "Suche zuerst Schachs, Schlagzüge und direkte Drohungen."
    @State private var completed = 0
    @State private var firstTryCorrect = 0
    @State private var startedAt = Date()

    private var puzzle: TrainingPuzzle? {
        puzzles.indices.contains(index) ? puzzles[index] : nil
    }

    var body: some View {
        ZStack {
            Color.coachBackground.ignoresSafeArea()
            if let p = puzzle {
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(spacing: 9) {
                            HStack {
                                Text(woodpecker ? "WOODPECKER" : "BLUNDER TRAINING")
                                    .font(.caption.bold()).foregroundStyle(Color.coachMint)
                                Spacer()
                                Text("\(index + 1)/\(puzzles.count)")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.68))
                            }
                            ProgressView(value: Double(index), total: Double(max(1, puzzles.count)))
                                .tint(Color.coachMint)
                        }
                        .padding(.horizontal, 7)

                        HStack {
                            Text(p.whiteToMove ? "Weiß am Zug" : "Schwarz am Zug")
                                .font(.headline)
                            Spacer()
                            Label(p.grade.shortLabel, systemImage: p.grade.symbol)
                                .foregroundStyle(p.grade.tint)
                                .font(.subheadline.bold())
                        }
                        .padding(.horizontal, 7)

                        ChessBoardViewLite(
                            fen: p.fen,
                            whiteAtBottom: p.whiteToMove,
                            highlightedMove: finishedPosition ? p.playedMove : nil,
                            suggestedMove: finishedPosition ? p.bestMove : nil,
                            selectedSquare: selected,
                            onSquareTap: { square in tapped(square, puzzle: p) }
                        )
                        .padding(.horizontal, 2)

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: finishedPosition ? "checkmark.seal.fill" : "brain.head.profile")
                                .font(.title3)
                                .foregroundStyle(finishedPosition ? Color.coachMint : Color.coachOrange)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(finishedPosition ? "Zug erklärt" : "Du bist am Zug")
                                    .font(.headline)
                                Text(finishedPosition ? p.explanation : message)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.72))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(15)
                        .background(Color.coachPanel, in: RoundedRectangle(cornerRadius: 15))

                        if finishedPosition {
                            Text("Besserer Zug: \(p.bestMove) · Damals gespielt: \(p.playedMove)")
                                .font(.footnote.monospaced())
                                .foregroundStyle(.white.opacity(0.70))
                            Button { next() } label: {
                                Label(index + 1 >= puzzles.count ? "Auswertung" : "Weiter", systemImage: "arrow.right")
                                    .frame(maxWidth: .infinity).padding(14)
                                    .background(Color.coachMint, in: RoundedRectangle(cornerRadius: 13))
                                    .foregroundStyle(.black).font(.headline)
                            }
                        } else {
                            Button {
                                revealed = true
                                finishedPosition = true
                                journal.finish(p, solvedWithoutHelp: false)
                                Haptics.move()
                            } label: {
                                Label("Lösung zeigen", systemImage: "book.closed")
                                    .frame(maxWidth: .infinity).padding(14)
                                    .foregroundStyle(.white)
                                    .background(Color.coachPanel2, in: RoundedRectangle(cornerRadius: 13))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(Color.coachMint)
                    Text("Training abgeschlossen")
                        .font(.title2.bold())
                    Text("\(completed) Aufgaben · \(firstTryCorrect) direkt richtig")
                        .font(.headline)
                    Text(woodpecker ? "Neuer Zyklus: Wiederhole dieselben Positionen schneller." :
                            "Schwierige Aufgaben erscheinen automatisch wieder.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                    Button("Fertig") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.coachMint)
                }
                .padding(28)
            }
        }
        .navigationTitle(woodpecker ? "Woodpecker" : "Blunder Training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.coachBackground, for: .navigationBar)
    }

    private func tapped(_ square: String, puzzle: TrainingPuzzle) {
        guard !finishedPosition else { return }
        if selected == square {
            selected = nil
            return
        }
        guard let from = selected else {
            selected = square
            message = "Zielfeld wählen."
            return
        }
        selected = nil
        let attempt = from + square
        if attempt == String(puzzle.bestMove.prefix(4)) {
            firstTryCorrect += didMistake ? 0 : 1
            journal.finish(puzzle, solvedWithoutHelp: !didMistake)
            finishedPosition = true
            message = "Genau. Das ist der beste Zug."
            Haptics.success()
        } else {
            didMistake = true
            message = "Noch nicht – achte auf ungedeckte Figuren und Königsangriffe."
            Haptics.error()
        }
    }

    private func next() {
        completed += 1
        index += 1
        selected = nil
        didMistake = false
        revealed = false
        finishedPosition = false
        message = "Suche zuerst Schachs, Schlagzüge und direkte Drohungen."
        Haptics.move()
    }
}

struct CoachInsightsView: View {
    @EnvironmentObject private var store: AppStore

    private var mostCommon: [(ReviewGrade, Int)] {
        let grades: [ReviewGrade] = [.blunder, .mistake, .miss, .inaccuracy]
        return grades.map { grade in
            (grade, store.games.reduce(0) { sum, game in
                sum + (game.review?.count(grade) ?? 0)
            })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.coachBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Dein Coach").font(.largeTitle.bold())
                        Text("Dein persönlicher Überblick auf Basis lokaler Partieanalysen.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.55))
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Analysierte Partien").font(.subheadline).foregroundStyle(.white.opacity(0.65))
                            Text("\(store.reviewedGamesCount)")
                                .font(.system(size: 46, weight: .heavy, design: .rounded))
                            Text("Durchschnittliche Genauigkeit: \(Int(store.averageAccuracy ?? 0)) %")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color.coachPanel, in: RoundedRectangle(cornerRadius: 18))
                        Text("Deine Muster").font(.headline)
                        ForEach(Array(mostCommon.enumerated()), id: \.offset) { entry in
                            let row = entry.element
                            HStack {
                                Image(systemName: row.0.symbol)
                                    .foregroundStyle(row.0.tint).frame(width: 25)
                                Text(row.0.rawValue)
                                Spacer()
                                Text("\(row.1)").monospacedDigit()
                            }
                            .font(.subheadline)
                            .padding(15)
                            .background(Color.coachPanel, in: RoundedRectangle(cornerRadius: 13))
                        }
                        Text("Keine erfundenen KI-Erklärungen: Die Zahlen stammen aus deinen lokal analysierten Partien.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.50))
                    }
                    .padding(18)
                }
            }
            .navigationBarHidden(true)
        }
    }
}
