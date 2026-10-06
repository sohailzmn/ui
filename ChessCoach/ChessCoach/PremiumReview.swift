import SwiftUI

enum PremiumReviewTab: String, CaseIterable {
    case report = "Report"
    case analysis = "Analyse"
    case insights = "Insights"

    var icon: String {
        switch self {
        case .report: return "chart.bar.fill"
        case .analysis: return "square.grid.2x2.fill"
        case .insights: return "lightbulb.fill"
        }
    }
}

struct PremiumReviewShellView: View {
    @Environment(\.dismiss) private var dismiss

    let game: ImportedGame
    let review: GameReview

    @State private var selectedTab: PremiumReviewTab = .report
    @State private var moveIndex: Int = 0
    @State private var showBestLine = false

    var body: some View {
        ZStack {
            Color.reviewBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.reviewPanelRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())

                    PremiumPlayerBar(game: game)
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 4)

                Group {
                    switch selectedTab {
                    case .report:
                        PremiumReportView(
                            game: game,
                            review: review,
                            startReview: {
                                moveIndex = firstImportantMove
                                selectedTab = .analysis
                                Haptics.keyMoment(review.moves[moveIndex].grade)
                            }
                        )
                    case .analysis:
                        PremiumAnalysisView(
                            game: game,
                            review: review,
                            moveIndex: $moveIndex,
                            showBestLine: $showBestLine
                        )
                    case .insights:
                        PremiumInsightsView(game: game, review: review)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                PremiumReviewTabBar(selectedTab: $selectedTab)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var firstImportantMove: Int {
        if let index = review.moves.firstIndex(where: { move in
            let mine = (game.myColor == "white" && move.ply % 2 == 1) ||
                (game.myColor == "black" && move.ply % 2 == 0)
            return mine && move.grade.isCritical
        }) {
            return index
        }
        return 0
    }
}

struct PremiumPlayerBar: View {
    let game: ImportedGame

    private var userIsWhite: Bool { game.myColor == "white" }

    var body: some View {
        HStack(spacing: 8) {
            playerPill(
                name: userIsWhite ? "Du" : game.opponent,
                rating: userIsWhite ? game.myRating : game.opponentRating,
                active: userIsWhite,
                piece: "W"
            )

            Text("VS")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.reviewGold)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.reviewGold.opacity(0.55), lineWidth: 1))

            playerPill(
                name: userIsWhite ? game.opponent : "Du",
                rating: userIsWhite ? game.opponentRating : game.myRating,
                active: !userIsWhite,
                piece: "B"
            )
        }
        .background(Color.reviewBackground)
    }

    private func playerPill(name: String, rating: Int, active: Bool, piece: String) -> some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? Color.reviewGold.opacity(0.18) : Color.white.opacity(0.07))
                Text(piece)
                    .font(.caption.bold())
                    .foregroundStyle(active ? Color.reviewGold : .white.opacity(0.52))
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(rating)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.38))
            }

            Spacer(minLength: 0)

            if active {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundStyle(Color.reviewGold)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Color.reviewPanel, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(active ? Color.reviewGold.opacity(0.5) : Color.white.opacity(0.055), lineWidth: 1))
    }
}

struct PremiumReportView: View {
    let game: ImportedGame
    let review: GameReview
    let startReview: () -> Void

    private var myMoves: [MoveReview] {
        review.moves.filter {
            (game.myColor == "white" && $0.ply % 2 == 1) ||
            (game.myColor == "black" && $0.ply % 2 == 0)
        }
    }

    private var opponentMoves: [MoveReview] {
        review.moves.filter {
            !((game.myColor == "white" && $0.ply % 2 == 1) ||
              (game.myColor == "black" && $0.ply % 2 == 0))
        }
    }

    private var opponentAccuracy: Double {
        if let stored = review.opponentAccuracy { return stored }
        guard !opponentMoves.isEmpty else { return 0 }
        return opponentMoves.map(\.derivedMoveAccuracy).reduce(0, +) / Double(opponentMoves.count)
    }

    private var trainingCount: Int {
        myMoves.filter { $0.grade.isTrainingCandidate }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PremiumCoachBubble(
                    grade: nil,
                    headline: reportHeadline,
                    body: review.lesson,
                    compact: false
                )

                PremiumEvalGraph(values: review.evaluationSeries ?? review.moves.map(\.evaluationAfter))

                scoreComparison

                moveBreakdown

                phaseSummary

                Button(action: startReview) {
                    Label("Review starten", systemImage: "magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.reviewGold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.reviewGold.opacity(0.18), radius: 10, y: 4)
                }
                .buttonStyle(PressScaleButtonStyle())

                if trainingCount > 0 {
                    NavigationLink {
                        MistakeTrainingView(gameID: game.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "target")
                                .font(.title3.bold())
                                .foregroundStyle(Color.reviewGold)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Learn from your mistakes")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(trainingCount) Positionen aus dieser Partie")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.45))
                            }

                            Spacer()

                            Text("\(trainingCount)")
                                .font(.caption.bold())
                                .foregroundStyle(Color.reviewGold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .overlay(Capsule().stroke(Color.reviewGold.opacity(0.65), lineWidth: 1))
                        }
                        .padding(16)
                        .background(Color.reviewPanel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.055), lineWidth: 1))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var scoreComparison: some View {
        HStack(spacing: 10) {
            PremiumScoreColumn(
                title: "Du",
                accuracy: review.accuracy,
                rating: review.performanceRating ?? game.myRating,
                highlighted: true
            )

            PremiumScoreColumn(
                title: game.opponent,
                accuracy: opponentAccuracy,
                rating: review.opponentGameRating ?? game.opponentRating,
                highlighted: false
            )
        }
    }

    private var moveBreakdown: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Zugbewertung")
                    .font(.headline)
                Spacer()
                Text("\(myMoves.count) Züge")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.40))
            }
            .padding(.bottom, 12)

            ForEach(ReviewGrade.allCases, id: \.self) { grade in
                let count = myMoves.filter { $0.grade == grade }.count
                if count > 0 {
                    PremiumBreakdownRow(grade: grade, count: count)
                }
            }
        }
        .padding(16)
        .background(Color.reviewPanel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.055), lineWidth: 1))
    }

    private var phaseSummary: some View {
        HStack(spacing: 8) {
            PremiumPhaseTile(title: "Eröffnung", value: review.openingAccuracy)
            PremiumPhaseTile(title: "Mittelspiel", value: review.middlegameAccuracy)
            PremiumPhaseTile(title: "Endspiel", value: review.endgameAccuracy)
        }
    }

    private var reportHeadline: String {
        switch review.accuracy {
        case 94...: return "Sehr starke Partie."
        case 86..<94: return "Sauber gespielt – wenige Schwächen."
        case 76..<86: return "Gute Partie mit klaren Lernmomenten."
        case 64..<76: return "Ein paar Momente haben viel gekostet."
        default: return "Hier steckt viel Trainingspotenzial drin."
        }
    }
}

struct PremiumScoreColumn: View {
    let title: String
    let accuracy: Double
    let rating: Int
    let highlighted: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(highlighted ? Color.reviewGold : .white)

            VStack(spacing: 2) {
                Text(String(format: "%.1f", accuracy))
                    .font(.system(size: 31, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text("Accuracy")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.38))
            }

            Divider().overlay(Color.white.opacity(0.07))

            VStack(spacing: 2) {
                Text("\(rating)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(highlighted ? Color.reviewGold : Color.white.opacity(0.82))
                Text("Game Rating")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(highlighted ? Color.reviewGold.opacity(0.055) : Color.reviewPanel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(highlighted ? Color.reviewGold.opacity(0.35) : Color.white.opacity(0.055), lineWidth: 1)
        )
    }
}

struct PremiumBreakdownRow: View {
    let grade: ReviewGrade
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(grade.tint.opacity(0.16))
                Text(grade.shortLabel)
                    .font(.caption.bold())
                    .foregroundStyle(grade.tint)
            }
            .frame(width: 34, height: 34)

            Text(grade.rawValue)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.76))

            Spacer()

            Text("\(count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.vertical, 6)
    }
}

struct PremiumPhaseTile: View {
    let title: String
    let value: Double?

    var body: some View {
        VStack(spacing: 5) {
            Text(value.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.38))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(Color.reviewPanel, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

struct PremiumAnalysisView: View {
    let game: ImportedGame
    let review: GameReview
    @Binding var moveIndex: Int
    @Binding var showBestLine: Bool

    private var move: MoveReview {
        review.moves[min(max(moveIndex, 0), max(review.moves.count - 1, 0))]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                PremiumCoachBubble(
                    grade: move.grade,
                    headline: move.simpleTitle,
                    body: simplifiedExplanation(move),
                    compact: true
                )

                HorizontalEvaluationBar(centipawns: showBestLine ? move.evaluationBefore : move.evaluationAfter)

                ChessBoardViewLite(
                    fen: showBestLine ? move.fenBefore : move.fenAfter,
                    whiteAtBottom: game.myColor == "white",
                    highlightedMove: showBestLine ? nil : move.move,
                    suggestedMove: showBestLine ? move.bestMove : nil
                )
                .background(Color.reviewBoardFrame, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))

                HStack {
                    Text("\(move.moveNumberText)  \(BoardMath.friendlyMove(move.move, in: move.fenBefore))")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(evalText(showBestLine ? move.evaluationBefore : move.evaluationAfter))
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 2)

                HStack(spacing: 8) {
                    Button {
                        showBestLine.toggle()
                        Haptics.move()
                    } label: {
                        Label(showBestLine ? "Dein Zug" : "Bester Zug", systemImage: showBestLine ? "arrow.uturn.backward" : "lightbulb.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(showBestLine ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(showBestLine ? Color.reviewPanel : Color.reviewGold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())

                    if move.grade.isTrainingCandidate {
                        NavigationLink {
                            MistakeTrainingView(gameID: game.id)
                        } label: {
                            Image(systemName: "target")
                                .font(.headline)
                                .foregroundStyle(Color.reviewGold)
                                .frame(width: 48, height: 44)
                                .background(Color.reviewPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }

                PremiumMoveStrip(review: review, selectedIndex: $moveIndex)

                HStack(spacing: 8) {
                    Button {
                        moveIndex = max(0, moveIndex - 1)
                        showBestLine = false
                        Haptics.move()
                    } label: {
                        Label("Zurück", systemImage: "chevron.left")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(moveIndex == 0)

                    Button {
                        moveIndex = min(review.moves.count - 1, moveIndex + 1)
                        showBestLine = false
                        Haptics.keyMoment(review.moves[min(review.moves.count - 1, moveIndex + 1)].grade)
                    } label: {
                        Label("Weiter", systemImage: "chevron.right")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(moveIndex >= review.moves.count - 1)
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .background(Color.reviewPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .onChange(of: moveIndex) { _, newValue in
            showBestLine = false
            if review.moves.indices.contains(newValue) {
                Haptics.keyMoment(review.moves[newValue].grade)
            }
        }
    }

    private func simplifiedExplanation(_ move: MoveReview) -> String {
        switch move.grade {
        case .brilliant:
            return "Schwer zu sehen – aber genau richtig. Du gibst kurzfristig etwas her und bekommst dafür die stärkere Stellung."
        case .great:
            return "Das war ein wichtiger Zug. Du hältst deine Stellung zusammen und lässt dem Gegner kaum gute Antworten."
        case .best:
            return "Genau der Zug, den Stockfish bevorzugt. Du machst deine Stellung besser, ohne etwas zu verschenken."
        case .excellent:
            return "Sehr stark. Der beste Zug wäre nur minimal genauer gewesen."
        case .good:
            return "Solide. Kein echter Fehler – aber \(move.bestMove) hätte etwas mehr Druck gemacht."
        case .book:
            return "Ein normaler, starker Eröffnungszug. Du entwickelst dich sinnvoll und kämpfst um das Zentrum."
        case .inaccuracy:
            return "\(move.bestMove) war einfacher. Dein Zug ist spielbar, macht die Stellung aber unnötig schwieriger."
        case .mistake:
            return "Hier verlierst du deutlich an Kontrolle. Mit \(move.bestMove) hättest du die Stellung stabil gehalten."
        case .miss:
            return "Hier lag eine klare Chance. \(move.bestMove) hätte die Partie deutlich zu deinen Gunsten gedreht."
        case .blunder:
            return "Dieser Zug gibt dem Gegner sofort einen großen Vorteil. \(move.bestMove) verhindert den Schaden."
        }
    }

    private func evalText(_ cp: Int) -> String {
        if cp > 90_000 { return "Mate" }
        if cp < -90_000 { return "-Mate" }
        return String(format: "%+.2f", Double(cp) / 100)
    }
}

struct PremiumCoachBubble: View {
    let grade: ReviewGrade?
    let headline: String
    let body: String
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image("Coach")
                .resizable()
                .scaledToFill()
                .frame(width: compact ? 46 : 54, height: compact ? 46 : 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke((grade?.tint ?? Color.reviewGold).opacity(0.35), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 5) {
                if let grade {
                    HStack(spacing: 7) {
                        Text(grade.shortLabel)
                            .font(.caption.bold())
                            .foregroundStyle(grade.tint)
                        Text(grade.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(grade.tint)
                    }
                }

                Text(headline)
                    .font(compact ? .headline : .title3.bold())
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)

                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.reviewCoachBubble, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.07), lineWidth: 1))
    }
}

struct HorizontalEvaluationBar: View {
    let centipawns: Int

    private var whiteFraction: CGFloat {
        if centipawns > 90_000 { return 0.97 }
        if centipawns < -90_000 { return 0.03 }
        let logistic = 1.0 / (1.0 + exp(-Double(centipawns) / 360.0))
        return CGFloat(min(0.97, max(0.03, logistic)))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.72))

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: geo.size.width * whiteFraction)
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.10), lineWidth: 1))
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: whiteFraction)
        }
        .frame(height: 28)
    }
}

struct PremiumMoveStrip: View {
    let review: GameReview
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(review.moves.indices, id: \.self) { index in
                        let move = review.moves[index]
                        Button {
                            selectedIndex = index
                            Haptics.keyMoment(move.grade)
                        } label: {
                            HStack(spacing: 6) {
                                Text(move.move)
                                    .font(.subheadline.bold().monospaced())
                                Text(move.grade.shortLabel)
                                    .font(.caption.bold())
                                    .foregroundStyle(move.grade.tint)
                            }
                            .foregroundStyle(index == selectedIndex ? Color.white : Color.white.opacity(0.62))
                            .padding(.horizontal, 11)
                            .frame(height: 40)
                            .background(
                                index == selectedIndex ? Color.reviewPanelRaised : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(index == selectedIndex ? Color.reviewGold.opacity(0.75) : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .id(index)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onChange(of: selectedIndex) { _, newValue in
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .frame(height: 46)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct PremiumInsightsView: View {
    let game: ImportedGame
    let review: GameReview

    private var myMoves: [MoveReview] {
        review.moves.filter {
            (game.myColor == "white" && $0.ply % 2 == 1) ||
            (game.myColor == "black" && $0.ply % 2 == 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PremiumCoachBubble(
                    grade: nil,
                    headline: "Das solltest du aus der Partie mitnehmen.",
                    body: review.lesson,
                    compact: false
                )

                insightCard(
                    icon: "scope",
                    title: "Größter Hebel",
                    text: biggestLesson,
                    tint: Color.reviewGold
                )

                insightCard(
                    icon: "checkmark.seal.fill",
                    title: "Was schon gut läuft",
                    text: strengthText,
                    tint: Color.coachMint
                )

                insightCard(
                    icon: "brain.head.profile",
                    title: "Nächste Trainingsregel",
                    text: trainingRule,
                    tint: Color.coachCyan
                )

                if review.criticalCount > 0 {
                    NavigationLink {
                        MistakeTrainingView(gameID: game.id)
                    } label: {
                        Label("Fehler jetzt trainieren", systemImage: "target")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.reviewGold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func insightCard(icon: String, title: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.reviewPanel, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.055), lineWidth: 1))
    }

    private var biggestLesson: String {
        if myMoves.contains(where: { $0.grade == .blunder }) {
            return "Vor jedem Zug zuerst prüfen: Was droht der Gegner direkt? Ein einziger Blunder kostet oft mehr als viele kleine Ungenauigkeiten."
        }
        if myMoves.contains(where: { $0.grade == .miss }) {
            return "In guten Stellungen zuerst forcing moves suchen: Schach, Schlag, direkte Drohung."
        }
        if myMoves.filter({ $0.grade == .mistake }).count >= 2 {
            return "An kritischen Stellen zwei Kandidatenzüge vergleichen, bevor du dich festlegst."
        }
        return "Deine Partie war stabil. Jetzt lohnt sich Feinarbeit bei Figurenaktivität und Zugreihenfolge."
    }

    private var strengthText: String {
        let positives = myMoves.filter { $0.grade.isPositive }.count
        return "\(positives) deiner Züge waren solide oder besser. Das Grundniveau stimmt – die großen Ausschläge sind wichtiger als kleine Abweichungen."
    }

    private var trainingRule: String {
        "Bei jeder kritischen Stellung: 1) gegnerische Drohung, 2) eigene Schachs, 3) Schläge, 4) erst dann ruhige Züge."
    }
}

struct PremiumEvalGraph: View {
    let values: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Partieverlauf")
                    .font(.headline)
                Spacer()
                Text("Stockfish")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.35))
            }

            Canvas { context, size in
                guard values.count > 1 else { return }

                var baseline = Path()
                baseline.move(to: CGPoint(x: 0, y: size.height / 2))
                baseline.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(baseline, with: .color(.white.opacity(0.10)), lineWidth: 1)

                var path = Path()
                for index in values.indices {
                    let cp = max(-900, min(900, values[index]))
                    let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * size.width
                    let y = size.height / 2 - CGFloat(cp) / 900 * size.height * 0.42

                    if index == values.startIndex {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    path,
                    with: .color(Color.reviewGold),
                    style: StrokeStyle(lineWidth: 2.7, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(height: 105)
            .padding(8)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(15)
        .background(Color.reviewPanel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.055), lineWidth: 1))
    }
}

struct PremiumReviewTabBar: View {
    @Binding var selectedTab: PremiumReviewTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PremiumReviewTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                    Haptics.selection()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(selectedTab == tab ? Color.white : Color.white.opacity(0.56))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        selectedTab == tab ? Color.reviewPanelRaised : Color.reviewPanel,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedTab == tab ? Color.reviewGold : Color.white.opacity(0.055), lineWidth: selectedTab == tab ? 1.5 : 1)
                    )
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color.reviewBackground)
    }
}

extension Color {
    static let reviewBackground = Color(red: 0.065, green: 0.067, blue: 0.072)
    static let reviewPanel = Color(red: 0.105, green: 0.108, blue: 0.115)
    static let reviewPanelRaised = Color(red: 0.145, green: 0.148, blue: 0.156)
    static let reviewBoardFrame = Color(red: 0.08, green: 0.082, blue: 0.088)
    static let reviewCoachBubble = Color(red: 0.94, green: 0.94, blue: 0.925)
    static let reviewGold = Color(red: 1.0, green: 0.72, blue: 0.11)
}
