import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showConnect = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        header

                        if store.username.isEmpty {
                            connectHero
                        } else {
                            coachHero
                            statRow
                            recentSection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 38)
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
            .task {
                if !store.username.isEmpty && store.games.isEmpty {
                    await store.sync()
                }
            }
            .coachErrorAlert(store: store)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.profile?.displayName ?? (store.username.isEmpty ? "Chess Coach" : store.username))
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(store.username.isEmpty ? "Trainiere aus deinen echten Partien" : "Dein persönliches Training")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            if let avatar = store.profile?.avatarURL, let url = URL(string: avatar) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        profilePlaceholder
                    }
                }
                .frame(width: 46, height: 46)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            } else {
                profilePlaceholder
                    .frame(width: 46, height: 46)
            }
        }
    }

    private var profilePlaceholder: some View {
        Circle()
            .fill(Color.coachPanel2)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundStyle(.white.opacity(0.7))
            )
    }

    private var connectHero: some View {
        VStack(spacing: 18) {
            AnimatedKnightHero()
                .frame(height: 235)

            VStack(spacing: 8) {
                Text("Lerne aus deinen eigenen Zügen.")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Verbinde nur deinen Chess.com-Namen. Die App holt deine öffentlichen Partien und zeigt dir mit Stockfish, wo du wirklich besser werden kannst.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                showConnect = true
            } label: {
                PrimaryButtonLabel(title: "Chess.com verbinden", systemImage: "link")
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(20)
        .coachPanel()
    }

    private var coachHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.coachPanel2, Color(red: 0.075, green: 0.20, blue: 0.17)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("TODAY'S MOVE")
                        .font(.caption.bold())
                        .tracking(1.7)
                        .foregroundStyle(Color.coachMint)

                    Text(trainingHeadline)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(trainingSubheadline)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(3)

                    NavigationLink {
                        if let game = store.games.first {
                            GameDetailView(gameID: game.id)
                        } else {
                            GamesView()
                        }
                    } label: {
                        Label(store.games.first?.review == nil ? "Letzte Partie reviewen" : "Review öffnen", systemImage: "arrow.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.coachMint)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .padding(.top, 3)
                }

                Spacer(minLength: 0)

                AnimatedKnightHero()
                    .frame(width: 118, height: 150)
                    .scaleEffect(0.62)
            }
            .padding(22)
        }
        .frame(minHeight: 205)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 1)
        )
    }

    private var trainingHeadline: String {
        if store.puzzles.count >= 3 { return "\(store.puzzles.count) Fehler warten auf ein Rematch" }
        if store.reviewedGamesCount == 0 { return "Dein erster Review ist bereit" }
        return "Mach aus Reviews echte Fortschritte"
    }

    private var trainingSubheadline: String {
        if store.puzzles.isEmpty {
            return "Öffne eine Partie und lass sie lokal analysieren. Daraus baut die App automatisch deine Übungen."
        }
        return "Statt nur eine Engine-Zahl zu sehen, bekommst du kritische Positionen noch einmal als Training."
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            StatMiniCard(
                title: store.profile?.ratingLabel ?? "Rating",
                value: store.profile?.rating.map(String.init) ?? "—",
                icon: "chart.line.uptrend.xyaxis"
            )

            StatMiniCard(
                title: "Reviews",
                value: "\(store.reviewedGamesCount)",
                icon: "sparkles"
            )

            StatMiniCard(
                title: "Accuracy",
                value: store.averageAccuracy.map { "\(Int($0.rounded()))%" } ?? "—",
                icon: "scope"
            )
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !store.games.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Letzte Partien")
                        .font(.title3.bold())
                    Spacer()
                    Text("\(store.games.count) geladen")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.46))
                }

                ForEach(store.games.prefix(3)) { game in
                    NavigationLink {
                        GameDetailView(gameID: game.id)
                    } label: {
                        GameRowCard(game: game)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }
}

struct StatMiniCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(Color.coachMint)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.48))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .coachPanel()
    }
}

struct ConnectView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""

    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: 22) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 46, height: 5)
                    .padding(.top, 8)

                Spacer(minLength: 5)

                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Color.coachMint)

                VStack(spacing: 8) {
                    Text("Dein Chess.com-Profil")
                        .font(.title.bold())

                    Text("Kein Passwort, kein Login. Nur dein öffentlicher Username wird verwendet.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                }

                TextField("z. B. hikaru", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.headline)
                    .padding(16)
                    .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                Button {
                    Task {
                        if await store.connect(username: username) {
                            dismiss()
                        }
                    }
                } label: {
                    if store.isSyncing {
                        HStack {
                            ProgressView()
                                .tint(.black)
                            Text(store.syncMessage.isEmpty ? "Verbinden…" : store.syncMessage)
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.coachMint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        PrimaryButtonLabel(title: "Partien laden", systemImage: "arrow.down.circle.fill")
                    }
                }
                .buttonStyle(PressScaleButtonStyle())
                .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSyncing)

                Text("Es werden die neuesten öffentlichen Standardpartien über die offizielle Chess.com PubAPI geladen.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.38))
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(.horizontal, 22)
        }
        .onAppear {
            username = store.username
        }
        .coachErrorAlert(store: store)
    }
}

struct GamesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var filter = "Alle"

    private let filters = ["Alle", "Gewonnen", "Verloren", "Reviewed"]

    private var filteredGames: [ImportedGame] {
        switch filter {
        case "Gewonnen": return store.games.filter { $0.result == "Win" }
        case "Verloren": return store.games.filter { $0.result == "Loss" }
        case "Reviewed": return store.games.filter { $0.review != nil }
        default: return store.games
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                if store.username.isEmpty {
                    EmptyStateView(
                        icon: "link.badge.plus",
                        title: "Noch kein Account",
                        message: "Verbinde zuerst deinen Chess.com-Username im Coach-Tab."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            filterBar

                            LazyVStack(spacing: 10) {
                                ForEach(filteredGames) { game in
                                    NavigationLink {
                                        GameDetailView(gameID: game.id)
                                    } label: {
                                        GameRowCard(game: game)
                                    }
                                    .buttonStyle(PressScaleButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 32)
                    }
                    .refreshable { await store.sync() }
                }
            }
            .navigationTitle("Deine Partien")
            .toolbarBackground(Color.coachBackground.opacity(0.9), for: .navigationBar)
            .coachErrorAlert(store: store)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { item in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            filter = item
                        }
                    } label: {
                        Text(item)
                            .font(.subheadline.bold())
                            .foregroundStyle(filter == item ? Color.black : Color.white.opacity(0.66))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                filter == item ? Color.coachMint : Color.white.opacity(0.06),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }
}

struct GameRowCard: View {
    let game: ImportedGame

    private var resultColor: Color {
        switch game.result {
        case "Win": return Color.coachMint
        case "Draw": return Color.coachOrange
        default: return Color.coachRed
        }
    }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(resultColor.opacity(0.14))
                Image(systemName: game.resultSymbol)
                    .foregroundStyle(resultColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text("vs \(game.opponent)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if game.review != nil {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(Color.coachMint)
                    }
                }

                Text("\(game.myRating) · \(game.timeClass.capitalized) · \(game.moveCount / 2 + game.moveCount % 2) Züge")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(game.result)
                    .font(.subheadline.bold())
                    .foregroundStyle(resultColor)

                if let accuracy = game.review?.accuracy {
                    Text("\(Int(accuracy.rounded()))% Review")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    Text(shortDate(game.endTime))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.38))
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.24))
        }
        .padding(15)
        .coachPanel()
    }
}

struct GameDetailView: View {
    @EnvironmentObject private var store: AppStore
    let gameID: String

    @State private var selectedPly = 0
    @State private var selectedReviewPly: Int?

    private var game: ImportedGame? {
        store.games.first(where: { $0.id == gameID })
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            if let game {
                ScrollView {
                    VStack(spacing: 18) {
                        gameHeader(game)
                        boardSection(game)
                        moveControls(game)

                        if let review = game.review {
                            reviewSummary(review)
                            reviewTimeline(game: game, review: review)

                            if let selected = selectedReview(game: game) {
                                MoveReviewCard(review: selected)
                            } else {
                                Text("Tippe auf einen markierten Zug, um die Erklärung und den besseren Zug zu sehen.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.42))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            }
                        } else {
                            startReviewCard(game)
                        }

                        if store.reviewingGameID == game.id {
                            ReviewProgressCard(progress: store.reviewProgress, status: store.reviewStatus)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 38)
                }
            } else {
                EmptyStateView(icon: "questionmark.square.dashed", title: "Partie nicht gefunden", message: "Synchronisiere deine Partien erneut.")
            }
        }
        .navigationTitle(game.map { "vs \($0.opponent)" } ?? "Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.coachBackground.opacity(0.92), for: .navigationBar)
        .coachErrorAlert(store: store)
    }

    private func gameHeader(_ game: ImportedGame) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(game.result == "Win" ? "Gewonnen" : game.result == "Draw" ? "Remis" : "Verloren")
                    .font(.title2.bold())
                Text("\(game.myRating) vs \(game.opponentRating) · \(game.timeClass.capitalized)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Text(game.myColor == "white" ? "♙" : "♟")
                .font(.system(size: 38))
                .frame(width: 54, height: 54)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .padding(.top, 6)
    }

    private func boardSection(_ game: ImportedGame) -> some View {
        let safePly = min(max(selectedPly, 0), max(0, game.fens.count - 1))
        let fen = game.fens.isEmpty ? "" : game.fens[safePly]
        let move = safePly > 0 && safePly - 1 < game.uciMoves.count ? game.uciMoves[safePly - 1] : nil
        let selectedReview = selectedReview(game: game)
        let evaluation = selectedReview?.evaluationBefore ?? evaluationAtPosition(game: game, ply: safePly)

        return VStack(spacing: 10) {
            BoardWithEvaluation(
                fen: selectedReview?.fenBefore ?? fen,
                whiteAtBottom: game.myColor == "white",
                evaluation: evaluation,
                highlightedMove: selectedReview == nil ? move : selectedReview?.move,
                suggestedMove: selectedReview?.bestMove
            )
            .padding(12)
            .coachPanel()

            HStack {
                Text("Position \(safePly) / \(game.uciMoves.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.44))

                Spacer()

                if let evaluation {
                    Text(evalText(evaluation))
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 5)
        }
    }

    private func moveControls(_ game: ImportedGame) -> some View {
        HStack(spacing: 10) {
            Button {
                selectedReviewPly = nil
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    selectedPly = max(0, selectedPly - 1)
                }
            } label: {
                controlButton(systemName: "chevron.left")
            }
            .buttonStyle(PressScaleButtonStyle())

            Button {
                selectedReviewPly = nil
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    selectedPly = 0
                }
            } label: {
                controlButton(systemName: "backward.end.fill")
            }
            .buttonStyle(PressScaleButtonStyle())

            Spacer()

            if selectedPly > 0 && selectedPly - 1 < game.uciMoves.count {
                Text(game.uciMoves[selectedPly - 1])
                    .font(.headline.monospaced())
                    .foregroundStyle(Color.coachMint)
            } else {
                Text("Start")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Button {
                selectedReviewPly = nil
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    selectedPly = min(game.uciMoves.count, selectedPly + 1)
                }
            } label: {
                controlButton(systemName: "chevron.right")
            }
            .buttonStyle(PressScaleButtonStyle())
        }
    }

    private func controlButton(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 46, height: 42)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func startReviewCard(_ game: ImportedGame) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Coach Review")
                        .font(.title3.bold())
                    Text("Stockfish prüft jeden Zug lokal auf deinem Gerät.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.54))
                }
                Spacer()
                Image(systemName: "cpu.fill")
                    .font(.title2)
                    .foregroundStyle(Color.coachMint)
            }

            Text("Du bekommst Bewertungsverlauf, bessere Züge, verständliche Hinweise und automatisch neue Trainingspositionen aus deinen Fehlern.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.64))
                .lineSpacing(3)

            Button {
                Task { await store.review(gameID: game.id) }
            } label: {
                PrimaryButtonLabel(title: "Kostenlosen Review starten", systemImage: "sparkles")
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(store.reviewingGameID != nil)
        }
        .padding(18)
        .coachPanel()
    }

    private func reviewSummary(_ review: GameReview) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dein Review")
                        .font(.headline)
                    Text(review.lesson)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.54))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(Int(review.accuracy.rounded()))")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Color.coachMint)
                    Text("Score")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            HStack(spacing: 8) {
                reviewCount("\(review.blunderCount)", "Blunder", Color.coachRed)
                reviewCount("\(review.mistakeCount)", "Fehler", Color.coachOrange)
                reviewCount("\(review.inaccuracyCount)", "Ungenau", Color.coachCyan)
            }
        }
        .padding(18)
        .coachPanel()
    }

    private func reviewCount(_ value: String, _ title: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.43))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func reviewTimeline(game: ImportedGame, review: GameReview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zug für Zug")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(review.moves) { move in
                        Button {
                            selectedReviewPly = move.ply
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                selectedPly = max(0, move.ply - 1)
                            }
                        } label: {
                            VStack(spacing: 5) {
                                Text(move.shortMoveNumber)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.45))

                                Image(systemName: move.grade.symbol)
                                    .font(.caption.bold())
                                    .foregroundStyle(move.grade.tint)

                                Text(move.move)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.white.opacity(0.78))
                                    .lineLimit(1)
                            }
                            .frame(width: 58, height: 68)
                            .background(
                                (selectedReviewPly == move.ply ? move.grade.tint.opacity(0.18) : Color.white.opacity(0.045)),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        selectedReviewPly == move.ply ? move.grade.tint.opacity(0.55) : Color.white.opacity(0.045),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
            }
        }
    }

    private func selectedReview(game: ImportedGame) -> MoveReview? {
        guard let selectedReviewPly else { return nil }
        return game.review?.moves.first(where: { $0.ply == selectedReviewPly })
    }

    private func evaluationAtPosition(game: ImportedGame, ply: Int) -> Int? {
        guard let review = game.review else { return nil }
        if ply == 0 { return review.moves.first?.evaluationBefore }
        return review.moves.first(where: { $0.ply == ply })?.evaluationAfter
    }

    private func evalText(_ cp: Int) -> String {
        if cp > 90_000 { return "M Weiß" }
        if cp < -90_000 { return "M Schwarz" }
        return String(format: "%+.2f", Double(cp) / 100.0)
    }
}

private extension MoveReview {
    var shortMoveNumber: String {
        let number = (ply + 1) / 2
        return ply % 2 == 1 ? "\(number)." : "\(number)…"
    }
}

struct MoveReviewCard: View {
    let review: MoveReview

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(review.grade.rawValue, systemImage: review.grade.symbol)
                    .font(.headline)
                    .foregroundStyle(review.grade.tint)

                Spacer()

                Text(review.move)
                    .font(.headline.monospaced())
                    .foregroundStyle(.white)
            }

            Text(review.explanation)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
                .lineSpacing(4)

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack(spacing: 12) {
                moveChip(title: "Gespielt", move: review.move, color: .white)
                moveChip(title: "Besser", move: review.bestMove.isEmpty ? "—" : review.bestMove, color: Color.coachMint)
            }

            if !review.principalVariation.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ENGINE-IDEE")
                        .font(.caption2.bold())
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.38))
                    Text(review.principalVariation.joined(separator: "  "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)
                }
            }
        }
        .padding(18)
        .coachPanel()
    }

    private func moveChip(title: String, move: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.38))
            Text(move)
                .font(.headline.monospaced())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

struct ReviewProgressCard: View {
    let progress: Double
    let status: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: max(0.01, progress))
                    .stroke(
                        LinearGradient(colors: [Color.coachMint, Color.coachCyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.45, dampingFraction: 0.86), value: progress)

                Text("\(Int(progress * 100))%")
                    .font(.headline.monospacedDigit().bold())
            }
            .frame(width: 84, height: 84)

            VStack(spacing: 4) {
                Text("Stockfish analysiert")
                    .font(.headline)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .coachPanel()
    }
}

struct LearnView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                if store.puzzles.isEmpty {
                    EmptyStateView(
                        icon: "brain.head.profile",
                        title: "Dein Training entsteht aus Reviews",
                        message: "Analysiere zuerst eine Partie. Fehler und Blunder werden hier automatisch zu Übungen."
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            learningHeader

                            ForEach(store.puzzles) { puzzle in
                                PuzzleCardView(puzzle: puzzle)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 36)
                    }
                }
            }
            .navigationTitle("Lernen")
            .toolbarBackground(Color.coachBackground.opacity(0.9), for: .navigationBar)
        }
    }

    private var learningHeader: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(store.puzzles.count) Positionen")
                        .font(.title2.bold())
                    Text("Alle stammen aus deinen eigenen kritischen Zügen.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.52))
                }

                Spacer()

                Image(systemName: "scope")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.coachMint)
            }
        }
    }
}

struct PuzzleCardView: View {
    let puzzle: TrainingPuzzle
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(puzzle.grade.rawValue, systemImage: puzzle.grade.symbol)
                    .font(.subheadline.bold())
                    .foregroundStyle(puzzle.grade.tint)

                Spacer()

                Text("vs \(puzzle.opponent)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }

            Text("Finde hier den besseren Zug.")
                .font(.title3.bold())

            ChessBoardViewLite(
                fen: puzzle.fen,
                whiteAtBottom: puzzle.whiteToMove,
                highlightedMove: revealed ? puzzle.playedMove : nil,
                suggestedMove: revealed ? puzzle.bestMove : nil
            )
            .padding(8)
            .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            if revealed {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Bester Zug")
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text(puzzle.bestMove)
                            .font(.headline.monospaced())
                            .foregroundStyle(Color.coachMint)
                    }

                    Text(puzzle.explanation)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineSpacing(3)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    revealed.toggle()
                }
            } label: {
                Label(revealed ? "Lösung ausblenden" : "Lösung zeigen", systemImage: revealed ? "eye.slash.fill" : "eye.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(revealed ? .white.opacity(0.66) : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(revealed ? Color.white.opacity(0.07) : Color.coachMint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(16)
        .coachPanel()
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showConnect = false
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        accountCard
                        engineCard
                        privacyCard

                        NavigationLink {
                            LicensesView()
                        } label: {
                            settingsRow(icon: "doc.text.fill", title: "Open-Source & Lizenzen", subtitle: "Stockfish, ChessCore und Quellen")
                        }
                        .buttonStyle(PressScaleButtonStyle())

                        if !store.username.isEmpty {
                            Button {
                                showClearConfirmation = true
                            } label: {
                                Label("Account & lokale Daten entfernen", systemImage: "trash.fill")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.coachRed)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .coachPanel()
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Setup")
            .toolbarBackground(Color.coachBackground.opacity(0.9), for: .navigationBar)
            .sheet(isPresented: $showConnect) {
                ConnectView()
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog("Lokale Chess-Coach-Daten entfernen?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Entfernen", role: .destructive) {
                    store.clearData()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Chess.com")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.username.isEmpty ? "Nicht verbunden" : store.username)
                        .font(.headline)
                    Text(store.username.isEmpty ? "Username hinzufügen" : "\(store.games.count) Partien lokal verfügbar")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.46))
                }

                Spacer()

                Button(store.username.isEmpty ? "Verbinden" : "Ändern") {
                    showConnect = true
                }
                .font(.subheadline.bold())
                .foregroundStyle(Color.coachMint)
            }

            if !store.username.isEmpty {
                Button {
                    Task { await store.sync() }
                } label: {
                    Label(store.isSyncing ? "Synchronisiert…" : "Partien aktualisieren", systemImage: "arrow.clockwise")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .foregroundStyle(.white)
                .buttonStyle(PressScaleButtonStyle())
                .disabled(store.isSyncing)
            }
        }
        .padding(17)
        .coachPanel()
    }

    private var engineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundStyle(Color.coachMint)
                Text("Lokale Analyse")
                    .font(.headline)
                Spacer()
                Text("FREE")
                    .font(.caption2.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.coachMint, in: Capsule())
            }

            Text("Stockfish läuft direkt in der App. Es gibt kein tägliches Review-Limit und keine bezahlte Engine-API.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.56))
                .lineSpacing(3)
        }
        .padding(17)
        .coachPanel()
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Privatsphäre", systemImage: "lock.fill")
                .font(.headline)
                .foregroundStyle(Color.coachCyan)

            Text("Es wird kein Chess.com-Passwort gespeichert. Die App liest ausschließlich öffentliche Profildaten und öffentliche PGNs über die PubAPI. Reviews bleiben lokal auf deinem Gerät.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.56))
                .lineSpacing(3)
        }
        .padding(17)
        .coachPanel()
    }

    private func settingsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .frame(width: 32, height: 32)
                .foregroundStyle(Color.coachMint)
                .background(Color.coachMint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(16)
        .coachPanel()
    }
}

struct LicensesView: View {
    private var notice: String {
        guard let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "Lizenzhinweise konnten nicht geladen werden."
        }
        return text
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                Text(notice)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
        }
        .navigationTitle("Open Source")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.coachMint)

            Text(title)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(28)
    }
}

private func shortDate(_ date: Date) -> String {
    date.formatted(.dateTime.day().month(.abbreviated))
}

private extension View {
    func coachErrorAlert(store: AppStore) -> some View {
        alert(
            "Chess Coach",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { showing in
                    if !showing { store.errorMessage = nil }
                }
            )
        ) {
            Button("OK") {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
