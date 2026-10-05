import SwiftUI

struct ReviewExperienceView: View {
    @EnvironmentObject private var store: AppStore
    let gameID: String

    @State private var guidedReview = false

    private var game: ImportedGame? {
        store.games.first(where: { $0.id == gameID })
    }

    var body: some View {
        ZStack {
            ReviewBackground()

            if let game {
                if store.reviewingGameID == game.id {
                    AnalysisProgressScreen(game: game)
                } else if let review = game.review, review.isModernReview {
                    if guidedReview {
                        GuidedReviewView(game: game, review: review) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                                guidedReview = false
                            }
                        }
                    } else {
                        ReviewReportView(game: game, review: review) {
                            Haptics.selection()
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                                guidedReview = true
                            }
                        }
                    }
                } else {
                    ReviewReadyView(game: game)
                }
            } else {
                EmptyStateView(
                    icon: "questionmark.square.dashed",
                    title: "Partie nicht gefunden",
                    message: "Synchronisiere deine Chess.com-Partien erneut."
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.055, green: 0.06, blue: 0.07).opacity(0.96), for: .navigationBar)
        .coachErrorAlert(store: store)
    }
}

private struct ReviewBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.045, green: 0.048, blue: 0.055)

            RadialGradient(
                colors: [Color(red: 0.16, green: 0.42, blue: 0.32).opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 520
            )

            RadialGradient(
                colors: [Color(red: 0.18, green: 0.23, blue: 0.36).opacity(0.18), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 540
            )
        }
        .ignoresSafeArea()
    }
}

private struct ReviewReadyView: View {
    @EnvironmentObject private var store: AppStore
    let game: ImportedGame

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CoachSpeechCard(
                    grade: nil,
                    headline: game.review == nil ? "Ich gehe die ganze Partie für dich durch." : "Für diese Partie gibt es jetzt den neuen Review.",
                    explanation: "Ich prüfe jeden Zug mit Stockfish, ordne ihn ein und erkläre dir danach in einfachen Worten, was gut war und was du beim nächsten Mal besser machen kannst.",
                    tip: "Erst kommt die komplette Analyse. Danach siehst du Accuracy, Spielniveau, Wendepunkte und den geführten Review."
                )
                .padding(.top, 8)

                VStack(spacing: 16) {
                    ReviewGameHeader(game: game)

                    ChessBoardViewLite(
                        fen: game.fens.last ?? game.fens.first ?? "",
                        whiteAtBottom: game.myColor == "white"
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.32), radius: 18, y: 10)

                    Button {
                        Haptics.selection()
                        Task { await store.review(gameID: game.id) }
                    } label: {
                        Label(game.review == nil ? "Game Review starten" : "Mit neuer Analyse neu reviewen", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundStyle(Color.black.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.48, green: 0.82, blue: 0.33), Color(red: 0.38, green: 0.72, blue: 0.27)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .padding(16)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 30)
        }
    }
}

private struct AnalysisProgressScreen: View {
    @EnvironmentObject private var store: AppStore
    let game: ImportedGame

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    .frame(width: 154, height: 154)

                Circle()
                    .trim(from: 0, to: max(0.015, store.reviewProgress))
                    .stroke(
                        AngularGradient(
                            colors: [Color.coachMint, Color.coachCyan, Color.coachMint],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 154, height: 154)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.45, dampingFraction: 0.88), value: store.reviewProgress)

                Image("CoachAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 102, height: 102)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .scaleEffect(pulse ? 1.035 : 0.975)
            }

            VStack(spacing: 9) {
                Text("Nox analysiert deine Partie")
                    .font(.system(size: 25, weight: .bold, design: .rounded))

                Text(store.reviewStatus.isEmpty ? "Stockfish wird vorbereitet" : store.reviewStatus)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)

                Text("\(Int(store.reviewProgress * 100))%")
                    .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.coachMint)
                    .padding(.top, 5)
            }

            VStack(spacing: 10) {
                ProgressStageRow(title: "Partie lesen", done: store.reviewProgress > 0.22)
                ProgressStageRow(title: "Jeden Zug bewerten", done: store.reviewProgress > 0.72)
                ProgressStageRow(title: "Coach-Erklärungen & Training", done: store.reviewProgress > 0.96)
            }
            .padding(16)
            .frame(maxWidth: 360)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("Die Analyse läuft lokal auf deinem Gerät. Es gibt kein tägliches Review-Limit.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.36))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)

            Spacer()
        }
        .padding(.horizontal, 22)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct ProgressStageRow: View {
    let title: String
    let done: Bool

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(done ? Color.coachMint : Color.white.opacity(0.32))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(done ? .white : .white.opacity(0.55))

            Spacer()
        }
    }
}

private struct ReviewReportView: View {
    let game: ImportedGame
    let review: GameReview
    let startReview: () -> Void

    private var myWhite: Bool { game.myColor == "white" }

    private var trainingCount: Int {
        review.moves.filter { move in
            let myMove = (move.ply % 2 == 1) == myWhite
            return myMove && move.grade.isTrainingCandidate
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CoachSpeechCard(
                    grade: nil,
                    headline: reportHeadline,
                    explanation: review.lesson,
                    tip: review.openingName.map { "Eröffnung: \($0)" } ?? "Jetzt gehen wir die Partie Zug für Zug durch."
                )
                .padding(.top, 6)

                EvaluationGraphCard(game: game, review: review)

                PlayerScoreCard(game: game, review: review)

                PhaseAccuracyCard(review: review)

                MoveBreakdownCard(game: game, review: review)

                Button(action: startReview) {
                    Label("Review starten", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(Color.black.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.50, green: 0.82, blue: 0.34), Color(red: 0.38, green: 0.70, blue: 0.26)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )
                        .shadow(color: Color.coachMint.opacity(0.14), radius: 18, y: 8)
                }
                .buttonStyle(PressScaleButtonStyle())

                if trainingCount > 0 {
                    NavigationLink {
                        MistakeTrainerView(gameID: game.id)
                    } label: {
                        HStack(spacing: 13) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.coachCyan.opacity(0.12))
                                Image(systemName: "brain.head.profile.fill")
                                    .foregroundStyle(Color.coachCyan)
                            }
                            .frame(width: 46, height: 46)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Learn from your mistakes")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(trainingCount) Position\(trainingCount == 1 ? "" : "en") aus dieser Partie nochmal lösen")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(15)
                        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }

                Text("Accuracy und Spielniveau sind lokale Schätzungen aus Stockfish-Auswertungen. Sie sind nicht die proprietären Chess.com-Werte.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 34)
        }
    }

    private var reportHeadline: String {
        if review.accuracy >= 92 { return "Sehr starke Partie." }
        if review.accuracy >= 82 { return "Das war insgesamt sauber." }
        if review.accuracy >= 68 { return "Gute Ideen – ein paar Momente kosten dich viel." }
        return "Hier steckt viel Lernpotenzial drin."
    }
}

private struct ReviewGameHeader: View {
    let game: ImportedGame

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("vs \(game.opponent)")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(game.myRating) · \(game.timeClass.capitalized) · \(game.moveCount / 2 + game.moveCount % 2) Züge")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()

            Text(game.result)
                .font(.subheadline.bold())
                .foregroundStyle(game.result == "Win" ? Color.coachMint : game.result == "Draw" ? Color.coachOrange : Color.coachRed)
        }
    }
}

private struct CoachSpeechCard: View {
    let grade: ReviewGrade?
    let headline: String
    let explanation: String
    let tip: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(spacing: 6) {
                Image("CoachAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                Text("NOX")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.42))
            }

            VStack(alignment: .leading, spacing: 7) {
                if let grade {
                    Label(grade.rawValue, systemImage: grade.symbol)
                        .font(.caption.bold())
                        .foregroundStyle(grade.tint)
                }

                Text(headline)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(tip)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.43))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.065))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke((grade?.tint ?? Color.white).opacity(0.10), lineWidth: 1)
                    )
            )
        }
    }
}

private struct EvaluationGraphCard: View {
    let game: ImportedGame
    let review: GameReview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Partieverlauf")
                        .font(.headline)
                    Text("Wo die Stellung gekippt ist")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.42))
                }

                Spacer()

                Text(review.openingName ?? "Game Review")
                    .font(.caption.bold())
                    .foregroundStyle(Color.coachMint)
                    .lineLimit(1)
            }

            EvaluationGraphView(moves: review.moves)
                .frame(height: 112)

            HStack {
                Label("Weiß besser", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))

                Spacer()

                Label("Schwarz besser", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct EvaluationGraphView: View {
    let moves: [MoveReview]

    var body: some View {
        Canvas { context, size in
            let baselineY = size.height / 2
            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: baselineY))
            baseline.addLine(to: CGPoint(x: size.width, y: baselineY))
            context.stroke(baseline, with: .color(Color.white.opacity(0.11)), lineWidth: 1)

            guard !moves.isEmpty else { return }

            var path = Path()
            for index in moves.indices {
                let x = moves.count == 1 ? size.width / 2 : CGFloat(index) / CGFloat(moves.count - 1) * size.width
                let cp = max(-800, min(800, moves[index].evaluationAfter))
                let normalized = CGFloat(cp + 800) / 1600
                let y = size.height - normalized * size.height

                if index == moves.startIndex {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [Color.coachCyan, Color.coachMint]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: size.width, y: size.height)
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
        }
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct PlayerScoreCard: View {
    let game: ImportedGame
    let review: GameReview

    var body: some View {
        HStack(spacing: 10) {
            scoreColumn(
                name: "Du",
                rating: game.myRating,
                accuracy: review.accuracy,
                gameRating: review.gameRating
            )

            scoreColumn(
                name: game.opponent,
                rating: game.opponentRating,
                accuracy: review.opponentAccuracy ?? 0,
                gameRating: review.opponentGameRating
            )
        }
    }

    private func scoreColumn(name: String, rating: Int, accuracy: Double, gameRating: Int?) -> some View {
        VStack(spacing: 12) {
            Text(name)
                .font(.subheadline.bold())
                .lineLimit(1)

            VStack(spacing: 2) {
                Text(String(format: "%.1f", accuracy))
                    .font(.system(size: 31, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.coachMint)
                Text("Accuracy")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(rating)")
                        .font(.subheadline.bold().monospacedDigit())
                    Text("Rating")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.38))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(gameRating.map(String.init) ?? "—")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(Color.coachCyan)
                    Text("Spielniveau")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.38))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(15)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct PhaseAccuracyCard: View {
    let review: GameReview

    var body: some View {
        HStack(spacing: 8) {
            phase("Eröffnung", review.openingAccuracy, "circle.grid.cross.fill")
            phase("Mittelspiel", review.middlegameAccuracy, "square.stack.3d.up.fill")
            phase("Endspiel", review.endgameAccuracy, "flag.checkered")
        }
    }

    private func phase(_ title: String, _ value: Double?, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.coachCyan)

            Text(value.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.headline.bold().monospacedDigit())

            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct MoveBreakdownCard: View {
    let game: ImportedGame
    let review: GameReview

    private var myWhite: Bool { game.myColor == "white" }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Zugqualität")
                    .font(.headline)
                Spacer()
                Text("DU")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(width: 32)
                Text("VS")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.28))
                    .frame(width: 32)
            }
            .padding(.bottom, 10)

            ForEach(ReviewGrade.allCases, id: \.self) { grade in
                let myCount = review.count(grade, forWhite: myWhite)
                let opponentCount = review.count(grade, forWhite: !myWhite)

                if myCount > 0 || opponentCount > 0 {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(grade.tint.opacity(0.16))
                            Image(systemName: grade.symbol)
                                .font(.caption.bold())
                                .foregroundStyle(grade.tint)
                        }
                        .frame(width: 29, height: 29)

                        Text(grade.rawValue)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Text("\(myCount)")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(grade.tint)
                            .frame(width: 32)

                        Text("\(opponentCount)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.46))
                            .frame(width: 32)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct GuidedReviewView: View {
    let game: ImportedGame
    let review: GameReview
    let close: () -> Void

    @State private var index = 0

    private var current: MoveReview {
        review.moves[min(max(index, 0), max(0, review.moves.count - 1))]
    }

    private var myMove: Bool {
        let whiteMove = current.ply % 2 == 1
        return (game.myColor == "white" && whiteMove) || (game.myColor == "black" && !whiteMove)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 13) {
                HStack {
                    Button(action: close) {
                        Label("Übersicht", systemImage: "chevron.left")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Spacer()

                    Text("\(current.moveNumberText) \(current.move)")
                        .font(.subheadline.bold().monospaced())
                        .foregroundStyle(current.grade.tint)

                    Spacer()

                    Text("\(index + 1)/\(review.moves.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 5)

                CoachSpeechCard(
                    grade: current.grade,
                    headline: current.headline ?? current.grade.rawValue,
                    explanation: current.explanation,
                    tip: current.coachTip ?? "Schau dir den vorgeschlagenen Zug direkt auf dem Brett an."
                )
                .id(current.ply)
                .transition(.opacity.combined(with: .move(edge: .top)))

                VStack(spacing: 8) {
                    BoardWithEvaluation(
                        fen: current.fenBefore,
                        whiteAtBottom: game.myColor == "white",
                        evaluation: current.evaluationBefore,
                        highlightedMove: current.move,
                        suggestedMove: current.bestMove == current.move ? nil : current.bestMove
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 1)

                    HStack {
                        evalLabel(current.evaluationBefore)

                        Spacer()

                        if current.bestMove != current.move, !current.bestMove.isEmpty {
                            Label(
                                "Besser: \(BoardMath.friendlyMove(current.bestMove, in: current.fenBefore))",
                                systemImage: "arrow.up.right"
                            )
                            .font(.caption.bold())
                            .foregroundStyle(Color.coachMint)
                            .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 5)
                }

                ReviewMoveRail(moves: review.moves, currentIndex: index) { newIndex in
                    go(to: newIndex)
                }

                HStack(spacing: 10) {
                    Button {
                        go(to: max(0, index - 1))
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(index == 0)
                    .opacity(index == 0 ? 0.35 : 1)

                    Button {
                        go(to: min(review.moves.count - 1, index + 1))
                    } label: {
                        HStack {
                            Text(index == review.moves.count - 1 ? "Fertig" : "Nächster Zug")
                            Image(systemName: index == review.moves.count - 1 ? "checkmark" : "chevron.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.black.opacity(0.86))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.coachMint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .disabled(index == review.moves.count - 1)
                    .opacity(index == review.moves.count - 1 ? 0.45 : 1)
                }

                if myMove, current.grade.isTrainingCandidate {
                    NavigationLink {
                        MistakeTrainerView(gameID: game.id, preferredPly: current.ply)
                    } label: {
                        Label("Diesen Fehler selbst lösen", systemImage: "brain.head.profile.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.coachCyan)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.coachCyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 30)
        }
        .onAppear {
            if let firstMine = review.moves.firstIndex(where: { move in
                let whiteMove = move.ply % 2 == 1
                return (game.myColor == "white" && whiteMove) || (game.myColor == "black" && !whiteMove)
            }) {
                index = firstMine
            }
            Haptics.reviewStep(current.grade)
        }
    }

    @ViewBuilder
    private func evalLabel(_ cp: Int) -> some View {
        let text: String = {
            if cp > 90_000 { return "Mate Weiß" }
            if cp < -90_000 { return "Mate Schwarz" }
            return String(format: "%+.2f", Double(cp) / 100.0)
        }()

        Text(text)
            .font(.caption.bold().monospacedDigit())
            .foregroundStyle(.white.opacity(0.56))
    }

    private func go(to newIndex: Int) {
        guard review.moves.indices.contains(newIndex), newIndex != index else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            index = newIndex
        }
        Haptics.reviewStep(review.moves[newIndex].grade)
    }
}

private struct ReviewMoveRail: View {
    let moves: [MoveReview]
    let currentIndex: Int
    let select: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(Array(moves.enumerated()), id: \.element.id) { item in
                    let idx = item.offset
                    let move = item.element

                    Button {
                        select(idx)
                    } label: {
                        VStack(spacing: 4) {
                            Text(move.moveNumberText)
                                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.36))

                            ZStack {
                                Circle()
                                    .fill(move.grade.tint.opacity(idx == currentIndex ? 0.28 : 0.11))
                                Image(systemName: move.grade.symbol)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(move.grade.tint)
                            }
                            .frame(width: 29, height: 29)
                            .overlay(
                                Circle()
                                    .stroke(idx == currentIndex ? move.grade.tint : Color.clear, lineWidth: 1.5)
                            )

                            Text(move.move)
                                .font(.system(size: 9, weight: .medium).monospaced())
                                .foregroundStyle(.white.opacity(0.54))
                        }
                        .frame(width: 48)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct MistakeTrainerView: View {
    @EnvironmentObject private var store: AppStore
    let gameID: String
    var preferredPly: Int? = nil

    @State private var currentIndex = 0
    @State private var selectedSquare: String?
    @State private var solved = false
    @State private var attempts = 0
    @State private var feedback = "Finde den Zug, den du jetzt spielen würdest."

    private var game: ImportedGame? {
        store.games.first(where: { $0.id == gameID })
    }

    private var candidates: [MoveReview] {
        guard let game, let review = game.review else { return [] }
        return review.moves.filter { move in
            let whiteMove = move.ply % 2 == 1
            let myMove = (game.myColor == "white" && whiteMove) || (game.myColor == "black" && !whiteMove)
            return myMove && move.grade.isTrainingCandidate && !move.bestMove.isEmpty
        }
    }

    private var current: MoveReview? {
        guard candidates.indices.contains(currentIndex) else { return nil }
        return candidates[currentIndex]
    }

    var body: some View {
        ZStack {
            ReviewBackground()

            if let game, let current {
                ScrollView {
                    VStack(spacing: 14) {
                        CoachSpeechCard(
                            grade: solved ? .best : current.grade,
                            headline: solved ? "Genau. Das ist die Idee." : "Deine Stellung. Dein Zug.",
                            explanation: solved ? current.explanation : feedback,
                            tip: solved ? (current.coachTip ?? "Merke dir das Muster.") : "Tippe zuerst eine Figur an und dann das Zielfeld."
                        )

                        InteractiveTrainingBoard(
                            fen: current.fenBefore,
                            whiteAtBottom: game.myColor == "white",
                            selectedSquare: selectedSquare,
                            suggestedMove: solved || attempts >= 2 ? current.bestMove : nil
                        ) { square in
                            handleTap(square: square, current: current, game: game)
                        }

                        HStack {
                            Text("Aufgabe \(currentIndex + 1) von \(candidates.count)")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.44))

                            Spacer()

                            if attempts >= 2, !solved {
                                Label("Hinweis eingeblendet", systemImage: "lightbulb.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.coachOrange)
                            }
                        }
                        .padding(.horizontal, 3)

                        if solved {
                            Button {
                                next()
                            } label: {
                                Label(currentIndex == candidates.count - 1 ? "Training beenden" : "Nächste Position", systemImage: "arrow.right")
                                    .font(.headline)
                                    .foregroundStyle(.black.opacity(0.86))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.coachMint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            } else {
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "Keine Fehler zum Trainieren",
                    message: "In dieser Partie gibt es aktuell keine markierten Trainingspositionen."
                )
            }
        }
        .navigationTitle("Learn from mistakes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let preferredPly,
               let match = candidates.firstIndex(where: { $0.ply == preferredPly }) {
                currentIndex = match
            }
        }
    }

    private func handleTap(square: String, current: MoveReview, game: ImportedGame) {
        guard !solved else { return }
        let board = BoardMath.pieces(from: current.fenBefore)

        if selectedSquare == nil {
            guard let piece = board[square] else {
                Haptics.error()
                feedback = "Wähle zuerst eine deiner Figuren."
                return
            }

            let shouldBeWhite = current.ply % 2 == 1
            guard piece.isUppercase == shouldBeWhite else {
                Haptics.error()
                feedback = "Das ist die gegnerische Figur. Du bist am Zug."
                return
            }

            selectedSquare = square
            Haptics.selection()
            feedback = "Gut. Wohin soll die Figur?"
            return
        }

        guard let from = selectedSquare else { return }

        if let piece = board[square] {
            let shouldBeWhite = current.ply % 2 == 1
            if piece.isUppercase == shouldBeWhite {
                selectedSquare = square
                Haptics.selection()
                return
            }
        }

        let attempted = from + square
        selectedSquare = nil

        if current.bestMove.hasPrefix(attempted) {
            solved = true
            feedback = "Richtig."
            Haptics.success()
        } else {
            attempts += 1
            Haptics.error()
            feedback = attempts >= 2
                ? "Noch nicht. Ich zeige dir jetzt mit dem Pfeil die Idee – versuch zu verstehen, warum dieser Zug das Problem löst."
                : "Nicht ganz. Schau zuerst nach Schachs, Schlägen und direkten Drohungen."
        }
    }

    private func next() {
        if currentIndex < candidates.count - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                currentIndex += 1
                selectedSquare = nil
                solved = false
                attempts = 0
                feedback = "Finde den Zug, den du jetzt spielen würdest."
            }
            Haptics.selection()
        }
    }
}

private struct InteractiveTrainingBoard: View {
    let fen: String
    let whiteAtBottom: Bool
    let selectedSquare: String?
    let suggestedMove: String?
    let tap: (String) -> Void

    private var files: [Character] {
        whiteAtBottom ? Array("abcdefgh") : Array("hgfedcba")
    }

    private var ranks: [Int] {
        whiteAtBottom ? Array((1...8).reversed()) : Array(1...8)
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 8
            let board = BoardMath.pieces(from: fen)
            let hintSquares = moveSquares(suggestedMove)

            VStack(spacing: 0) {
                ForEach(ranks, id: \.self) { rank in
                    HStack(spacing: 0) {
                        ForEach(files, id: \.self) { file in
                            let square = "\(file)\(rank)"
                            let fileIndex = Int(file.asciiValue ?? 97) - 97
                            let isLight = (fileIndex + rank) % 2 == 1

                            Button {
                                tap(square)
                            } label: {
                                ZStack {
                                    Rectangle()
                                        .fill(boardColor(isLight: isLight, selected: selectedSquare == square, hinted: hintSquares.contains(square)))

                                    if let piece = board[square] {
                                        Image(assetName(piece))
                                            .resizable()
                                            .scaledToFit()
                                            .padding(cell * 0.035)
                                            .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                                    }
                                }
                                .frame(width: cell, height: cell)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func boardColor(isLight: Bool, selected: Bool, hinted: Bool) -> Color {
        if selected { return Color.coachCyan.opacity(0.68) }
        if hinted { return Color.coachMint.opacity(isLight ? 0.62 : 0.48) }
        return isLight
            ? Color(red: 0.82, green: 0.82, blue: 0.76)
            : Color(red: 0.31, green: 0.45, blue: 0.38)
    }

    private func moveSquares(_ move: String?) -> Set<String> {
        guard let move, move.count >= 4 else { return [] }
        let chars = Array(move)
        return [String(chars[0...1]), String(chars[2...3])]
    }

    private func assetName(_ piece: Character) -> String {
        let prefix = piece.isUppercase ? "w" : "b"
        return prefix + String(piece).uppercased()
    }
}
