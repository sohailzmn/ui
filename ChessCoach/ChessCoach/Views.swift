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
                            ReviewExperienceView(gameID: game.id)
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
                        ReviewExperienceView(gameID: game.id)
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
                                        ReviewExperienceView(gameID: game.id)
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

    @State private var mode: ReviewScreenMode = .report
    @State private var reviewIndex = 0

    private var game: ImportedGame? {
        store.games.first(where: { $0.id == gameID })
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            if let game {
                if let review = game.review {
                    switch mode {
                    case .report:
                        ReviewReportView(
                            game: game,
                            review: review,
                            onStartReview: {
                                reviewIndex = firstInterestingIndex(game: game, review: review)
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                    mode = .coach
                                }
                                Haptics.keyMoment(review.moves[reviewIndex].grade)
                            }
                        )
                    case .coach:
                        CoachReviewView(
                            game: game,
                            review: review,
                            selectedIndex: $reviewIndex,
                            onShowReport: {
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                    mode = .report
                                }
                            }
                        )
                    }
                } else {
                    preReviewView(game)
                }
            } else {
                EmptyStateView(
                    icon: "questionmark.square.dashed",
                    title: "Partie nicht gefunden",
                    message: "Synchronisiere deine Partien erneut."
                )
            }
        }
        .navigationTitle(game.map { "vs \($0.opponent)" } ?? "Game Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.coachBackground.opacity(0.96), for: .navigationBar)
        .coachErrorAlert(store: store)
    }

    private func preReviewView(_ game: ImportedGame) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                compactGameHeader(game)

                ChessBoardViewLite(
                    fen: game.fens.last ?? "",
                    whiteAtBottom: game.myColor == "white",
                    highlightedMove: game.uciMoves.last
                )
                .padding(.horizontal, 2)

                if store.reviewingGameID == game.id {
                    ReviewProgressCard(progress: store.reviewProgress, status: store.reviewStatus)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image("Coach")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 58, height: 58)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.coachMint.opacity(0.35), lineWidth: 1.5))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Coach Nox")
                                    .font(.headline)
                                Text("Ich gehe erst durch die ganze Partie. Danach bekommst du deinen Report und wir schauen uns jeden Zug gemeinsam an.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.62))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Button {
                            Task { await store.review(gameID: game.id) }
                        } label: {
                            PrimaryButtonLabel(title: "Game Review starten", systemImage: "sparkles")
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                    .padding(18)
                    .coachPanel()
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 36)
        }
    }

    private func compactGameHeader(_ game: ImportedGame) -> some View {
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
                .font(.system(size: 36))
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
    }

    private func firstInterestingIndex(game: ImportedGame, review: GameReview) -> Int {
        if let index = review.moves.firstIndex(where: { move in
            let mine = (game.myColor == "white" && move.ply % 2 == 1) || (game.myColor == "black" && move.ply % 2 == 0)
            return mine && (move.isKeyMoment ?? false)
        }) {
            return index
        }
        return 0
    }
}

private enum ReviewScreenMode {
    case report
    case coach
}

struct ReviewReportView: View {
    let game: ImportedGame
    let review: GameReview
    let onStartReview: () -> Void

    private var myMoves: [MoveReview] {
        review.moves.filter {
            (game.myColor == "white" && $0.ply % 2 == 1) || (game.myColor == "black" && $0.ply % 2 == 0)
        }
    }

    private var trainableCount: Int {
        myMoves.filter { [.inaccuracy, .mistake, .miss, .blunder].contains($0.grade) }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                reportHero
                EvaluationGraphCard(values: review.evaluationSeries ?? review.moves.map(\.evaluationAfter))
                classificationCard
                coachSummary

                Button(action: onStartReview) {
                    PrimaryButtonLabel(title: "Review Zug für Zug", systemImage: "play.fill")
                }
                .buttonStyle(PressScaleButtonStyle())

                if trainableCount > 0 {
                    NavigationLink {
                        MistakeTrainingView(gameID: game.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "target")
                                .font(.title3.bold())
                                .foregroundStyle(Color.coachMint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Learn from your mistakes")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(trainableCount) Positionen aus genau dieser Partie trainieren")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.50))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.28))
                        }
                        .padding(17)
                        .coachPanel()
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    private var reportHero: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GAME REVIEW")
                        .font(.caption.bold())
                        .tracking(1.7)
                        .foregroundStyle(Color.coachMint)
                    Text(reportHeadline)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("gegen \(game.opponent) · \(game.timeClass.capitalized)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                Image("Coach")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            }

            HStack(spacing: 10) {
                scoreTile(
                    title: "Accuracy",
                    value: "\(Int(review.accuracy.rounded()))%",
                    subtitle: accuracyWord,
                    tint: Color.coachMint
                )
                scoreTile(
                    title: "Game Rating",
                    value: "\(review.performanceRating ?? game.myRating)",
                    subtitle: "Performance",
                    tint: Color.coachCyan
                )
            }
        }
        .padding(19)
        .background(
            LinearGradient(
                colors: [Color.coachPanel2, Color(red: 0.075, green: 0.17, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func scoreTile(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(tint)
            Text(subtitle)
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var classificationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Deine Züge")
                    .font(.headline)
                Spacer()
                Text("\(myMoves.count) bewertet")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                ForEach(ReviewGrade.allCases, id: \.self) { grade in
                    let count = myMoves.filter { $0.grade == grade }.count
                    if count > 0 {
                        HStack(spacing: 9) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(grade.tint.opacity(0.15))
                                Text(grade.shortLabel)
                                    .font(.caption.bold())
                                    .foregroundStyle(grade.tint)
                            }
                            .frame(width: 34, height: 34)

                            Text(grade.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.78))
                            Spacer()
                            Text("\(count)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .padding(17)
        .coachPanel()
    }

    private var coachSummary: some View {
        HStack(alignment: .top, spacing: 13) {
            Image("Coach")
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("Nox' Fazit")
                    .font(.headline)
                Text(review.lesson)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .coachPanel()
    }

    private var reportHeadline: String {
        switch review.accuracy {
        case 95...: return "Fast fehlerfrei gespielt."
        case 88..<95: return "Starke Partie."
        case 78..<88: return "Gut – mit klaren Lernmomenten."
        case 65..<78: return "Da steckt viel Potenzial drin."
        default: return "Diese Partie lohnt sich zu trainieren."
        }
    }

    private var accuracyWord: String {
        switch review.accuracy {
        case 95...: return "Elite"
        case 88..<95: return "Sehr stark"
        case 78..<88: return "Stark"
        case 65..<78: return "Solide"
        default: return "Trainierbar"
        }
    }
}

struct EvaluationGraphCard: View {
    let values: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Partieverlauf")
                    .font(.headline)
                Spacer()
                Text("Stockfish")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.38))
            }

            Canvas { context, size in
                guard values.count > 1 else { return }
                let clamped = values.map { max(-900, min(900, $0)) }
                let midY = size.height / 2

                var zero = Path()
                zero.move(to: CGPoint(x: 0, y: midY))
                zero.addLine(to: CGPoint(x: size.width, y: midY))
                context.stroke(zero, with: .color(.white.opacity(0.12)), lineWidth: 1)

                var path = Path()
                for (index, value) in clamped.enumerated() {
                    let x = CGFloat(index) / CGFloat(max(clamped.count - 1, 1)) * size.width
                    let normalized = CGFloat(value) / 900
                    let y = midY - normalized * (size.height * 0.43)
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .linearGradient(
                    Gradient(colors: [Color.coachCyan, Color.coachMint]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                ), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 118)
            .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack {
                Label("Schwarz besser", systemImage: "circle.fill")
                Spacer()
                Label("Weiß besser", systemImage: "circle.fill")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.36))
        }
        .padding(17)
        .coachPanel()
    }
}

struct CoachReviewView: View {
    let game: ImportedGame
    let review: GameReview
    @Binding var selectedIndex: Int
    let onShowReport: () -> Void

    @State private var showBest = false

    private var current: MoveReview {
        review.moves[min(max(selectedIndex, 0), max(review.moves.count - 1, 0))]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                CoachMessageCard(move: current)

                BoardWithEvaluation(
                    fen: showBest ? current.fenBefore : current.fenAfter,
                    whiteAtBottom: game.myColor == "white",
                    evaluation: showBest ? current.evaluationBefore : current.evaluationAfter,
                    highlightedMove: showBest ? nil : current.move,
                    suggestedMove: showBest ? current.bestMove : nil
                )
                .padding(.horizontal, 1)

                HStack {
                    Text("\(current.moveNumberText) \(current.move)")
                        .font(.headline.monospaced())
                    Spacer()
                    Text(evalText(current.evaluationAfter))
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.white.opacity(0.56))
                }
                .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    Button {
                        showBest.toggle()
                        Haptics.move()
                    } label: {
                        Label(showBest ? "Gespielten Zug" : "Besten Zug", systemImage: showBest ? "arrow.uturn.backward" : "lightbulb.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(showBest ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(showBest ? Color.white.opacity(0.07) : Color.coachMint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())

                    Button(action: onShowReport) {
                        Image(systemName: "chart.bar.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 44)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }

                if showBest && !current.principalVariation.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SO GEHT DIE IDEE WEITER")
                            .font(.caption2.bold())
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.38))
                        Text(current.principalVariation.joined(separator: "  "))
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                reviewControls

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(review.moves.enumerated()), id: \.element.id) { index, move in
                            Button {
                                selectedIndex = index
                                showBest = false
                                Haptics.keyMoment(move.grade)
                            } label: {
                                VStack(spacing: 3) {
                                    Text(move.moveNumberText.replacingOccurrences(of: "...", with: "…"))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.34))
                                    Text(move.grade.shortLabel)
                                        .font(.caption.bold())
                                        .foregroundStyle(move.grade.tint)
                                    Text(move.move)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.white.opacity(0.72))
                                }
                                .frame(width: 55, height: 61)
                                .background(
                                    selectedIndex == index ? move.grade.tint.opacity(0.15) : Color.white.opacity(0.03),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                }

                if review.criticalCount > 0 {
                    NavigationLink {
                        MistakeTrainingView(gameID: game.id)
                    } label: {
                        Label("Learn from your mistakes", systemImage: "target")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.coachMint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .onChange(of: selectedIndex) { _, newValue in
            showBest = false
            if review.moves.indices.contains(newValue) {
                Haptics.keyMoment(review.moves[newValue].grade)
            }
        }
    }

    private var reviewControls: some View {
        HStack(spacing: 10) {
            Button {
                selectedIndex = max(0, selectedIndex - 1)
            } label: {
                Label("Zurück", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .disabled(selectedIndex == 0)

            Button {
                selectedIndex = min(review.moves.count - 1, selectedIndex + 1)
            } label: {
                Label("Weiter", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity)
            }
            .disabled(selectedIndex >= review.moves.count - 1)
        }
        .font(.subheadline.bold())
        .foregroundStyle(.white)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .buttonStyle(PressScaleButtonStyle())
    }

    private func evalText(_ cp: Int) -> String {
        if cp > 90_000 { return "Mate · Weiß" }
        if cp < -90_000 { return "Mate · Schwarz" }
        return String(format: "%+.2f", Double(cp) / 100.0)
    }
}

struct CoachMessageCard: View {
    let move: MoveReview

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("Coach")
                .resizable()
                .scaledToFill()
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(move.grade.tint.opacity(0.36), lineWidth: 1.5)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(move.grade.shortLabel)
                        .font(.caption.bold())
                        .foregroundStyle(move.grade.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(move.grade.tint.opacity(0.13), in: Capsule())

                    Text(move.grade.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(move.grade.tint)
                }

                Text(move.simpleTitle)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(move.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(
            LinearGradient(
                colors: [move.grade.tint.opacity(0.11), Color.coachPanel.opacity(0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(move.grade.tint.opacity(0.13), lineWidth: 1)
        )
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
                        message: "Analysiere zuerst eine Partie. Deine echten Ungenauigkeiten, Fehler, Misses und Blunder werden hier zu Übungen."
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            trainingHero

                            NavigationLink {
                                MistakeTrainingView(gameID: nil)
                            } label: {
                                HStack(spacing: 13) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.coachMint.opacity(0.13))
                                        Image(systemName: "target")
                                            .font(.title2.bold())
                                            .foregroundStyle(Color.coachMint)
                                    }
                                    .frame(width: 54, height: 54)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Learn from your mistakes")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text("Trainiere alle \(store.puzzles.count) Positionen aktiv auf dem Brett.")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.50))
                                    }

                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white.opacity(0.28))
                                }
                                .padding(16)
                                .coachPanel()
                            }
                            .buttonStyle(PressScaleButtonStyle())

                            Text("Aus deinen Partien")
                                .font(.headline)
                                .padding(.top, 3)

                            ForEach(store.puzzles.prefix(12)) { puzzle in
                                NavigationLink {
                                    MistakeTrainingView(gameID: puzzle.gameID)
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(puzzle.grade.shortLabel)
                                            .font(.headline.bold())
                                            .foregroundStyle(puzzle.grade.tint)
                                            .frame(width: 42, height: 42)
                                            .background(puzzle.grade.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("vs \(puzzle.opponent)")
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.white)
                                            Text("Zug \((puzzle.ply + 1) / 2) · \(puzzle.grade.rawValue)")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.45))
                                        }

                                        Spacer()
                                        Text("Trainieren")
                                            .font(.caption.bold())
                                            .foregroundStyle(Color.coachMint)
                                    }
                                    .padding(14)
                                    .coachPanel()
                                }
                                .buttonStyle(PressScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 36)
                    }
                }
            }
            .navigationTitle("Lernen")
            .toolbarBackground(Color.coachBackground.opacity(0.94), for: .navigationBar)
        }
    }

    private var trainingHero: some View {
        HStack(spacing: 14) {
            Image("Coach")
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Deine Fehler. Dein Training.")
                    .font(.title3.bold())
                Text("Keine Zufallspuzzles – nur Positionen, die du selbst in echten Partien falsch gespielt hast.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .background(
            LinearGradient(
                colors: [Color.coachPanel2, Color.coachMint.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

struct MistakeTrainingView: View {
    @EnvironmentObject private var store: AppStore
    let gameID: String?

    @State private var index = 0
    @State private var selectedSquare: String?
    @State private var solved = false
    @State private var revealed = false
    @State private var feedback: String?

    private var puzzles: [TrainingPuzzle] {
        if let gameID {
            return store.puzzles.filter { $0.gameID == gameID }
        }
        return store.puzzles
    }

    private var current: TrainingPuzzle? {
        guard !puzzles.isEmpty else { return nil }
        return puzzles[min(index, puzzles.count - 1)]
    }

    private var currentGame: ImportedGame? {
        guard let current else { return nil }
        return store.games.first(where: { $0.id == current.gameID })
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            if let puzzle = current {
                ScrollView {
                    VStack(spacing: 14) {
                        trainingCoach(puzzle)

                        ChessBoardViewLite(
                            fen: puzzle.fen,
                            whiteAtBottom: currentGame?.myColor == "white",
                            highlightedMove: solved || revealed ? puzzle.playedMove : nil,
                            suggestedMove: solved || revealed ? puzzle.bestMove : nil,
                            selectedSquare: selectedSquare,
                            onSquareTap: { square in
                                tap(square, puzzle: puzzle)
                            }
                        )
                        .padding(.horizontal, 1)

                        HStack {
                            Text("\(index + 1) / \(puzzles.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.42))
                            Spacer()
                            Text("Dein Zug: \(puzzle.playedMove)")
                                .font(.caption.monospaced())
                                .foregroundStyle(puzzle.grade.tint)
                        }
                        .padding(.horizontal, 4)

                        if let feedback {
                            Text(feedback)
                                .font(.subheadline.bold())
                                .foregroundStyle(solved ? Color.coachMint : Color.coachOrange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(13)
                                .background((solved ? Color.coachMint : Color.coachOrange).opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if solved || revealed {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Warum?")
                                    .font(.headline)
                                Text(puzzle.explanation)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.64))
                                    .lineSpacing(3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(15)
                            .coachPanel()
                        }

                        HStack(spacing: 9) {
                            if !solved && !revealed {
                                Button {
                                    revealed = true
                                    selectedSquare = nil
                                    feedback = "Der bessere Zug ist \(puzzle.bestMove). Schau dir den Pfeil an und versuche die Idee zu verstehen."
                                    Haptics.move()
                                } label: {
                                    Label("Lösung", systemImage: "lightbulb.fill")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                }
                                .buttonStyle(PressScaleButtonStyle())
                            }

                            if solved || revealed {
                                Button {
                                    nextPuzzle()
                                } label: {
                                    Label(index + 1 < puzzles.count ? "Nächste Position" : "Nochmal", systemImage: "arrow.right")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(Color.coachMint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                }
                                .buttonStyle(PressScaleButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
            } else {
                EmptyStateView(icon: "checkmark.seal.fill", title: "Alles trainiert", message: "Für diese Partie gibt es keine kritischen Positionen.")
            }
        }
        .navigationTitle("Mistake Trainer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.coachBackground.opacity(0.95), for: .navigationBar)
    }

    private func trainingCoach(_ puzzle: TrainingPuzzle) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image("Coach")
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(puzzle.grade == .blunder ? "Hol dir diesen Zug zurück." : "Finde jetzt den besseren Zug.")
                    .font(.headline)
                Text("Tippe zuerst die Figur und dann das Zielfeld. Ich sage dir sofort, ob die Idee stimmt.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .coachPanel()
    }

    private func tap(_ square: String, puzzle: TrainingPuzzle) {
        guard !solved && !revealed else { return }

        if selectedSquare == square {
            selectedSquare = nil
            feedback = nil
            return
        }

        guard let from = selectedSquare else {
            selectedSquare = square
            feedback = "Jetzt das Zielfeld wählen."
            return
        }

        let attempt = from + square
        let target = String(puzzle.bestMove.prefix(4))
        selectedSquare = nil

        if attempt == target {
            solved = true
            feedback = "Genau. Das ist die Idee – \(puzzle.bestMove) war hier der Zug."
            Haptics.success()
        } else {
            feedback = "Noch nicht. Prüfe zuerst Schach, Schlag und direkte Drohungen."
            Haptics.error()
        }
    }

    private func nextPuzzle() {
        if index + 1 < puzzles.count {
            index += 1
        } else {
            index = 0
        }
        selectedSquare = nil
        solved = false
        revealed = false
        feedback = nil
        Haptics.move()
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

extension View {
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
