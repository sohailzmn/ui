import Foundation
import ChessCore
import SFEngine

enum ChessParser {
    static func parsePGN(_ pgn: String) throws -> (moves: [String], fens: [String]) {
        do {
            let parsed = try PGNSerializer().game(from: pgn)
            let moves = parsed.mainlineMoves
            let uciMoves = moves.map(\.description)

            let replay = ChessCore.Game()
            var fens = [Position.standardStartingFEN]

            for move in moves {
                try replay.applyLegal(move: move)
                fens.append(FENSerializer().fen(from: replay.position))
            }

            return (uciMoves, fens)
        } catch {
            throw ChessCoachError.malformedGame
        }
    }
}

struct ChessComService {
    private let decoder = JSONDecoder()

    func loadPlayer(username rawUsername: String) async throws -> (PlayerSnapshot, [ImportedGame]) {
        let username = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard username.range(of: #"^[A-Za-z0-9_-]{2,30}$"#, options: .regularExpression) != nil else {
            throw ChessCoachError.invalidUsername
        }

        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username

        let profile: ChessComProfileDTO
        do {
            profile = try await requestJSON("https://api.chess.com/pub/player/\(encoded)")
        } catch let error as HTTPError where error.statusCode == 404 {
            throw ChessCoachError.playerNotFound
        }

        let stats: ChessComStatsDTO? = try? await requestJSON("https://api.chess.com/pub/player/\(encoded)/stats")
        let archives: ChessComArchiveList = try await requestJSON("https://api.chess.com/pub/player/\(encoded)/games/archives")

        var imported: [ImportedGame] = []
        let recentArchives = Array(archives.archives.suffix(6)).reversed()

        for archiveURL in recentArchives {
            let archive: ChessComArchive = try await requestJSON(archiveURL)
            for dto in archive.games.reversed() {
                guard imported.count < 80 else { break }
                guard dto.rules == nil || dto.rules == "chess", let pgn = dto.pgn, !pgn.isEmpty else { continue }
                guard let parsed = try? ChessParser.parsePGN(pgn) else { continue }

                let isWhite = dto.white.username.caseInsensitiveCompare(profile.username) == .orderedSame
                let me = isWhite ? dto.white : dto.black
                let opponent = isWhite ? dto.black : dto.white
                let gameID = dto.uuid ?? dto.url

                imported.append(
                    ImportedGame(
                        id: gameID,
                        chessComURL: dto.url,
                        pgn: pgn,
                        opponent: opponent.username,
                        opponentRating: opponent.rating,
                        myRating: me.rating,
                        myColor: isWhite ? "white" : "black",
                        result: resultText(from: me.result),
                        timeClass: dto.timeClass ?? "chess",
                        endTime: Date(timeIntervalSince1970: TimeInterval(dto.endTime)),
                        uciMoves: parsed.moves,
                        fens: parsed.fens,
                        review: nil
                    )
                )
            }
            if imported.count >= 80 { break }
        }

        guard !imported.isEmpty else { throw ChessCoachError.noGames }

        imported.sort { $0.endTime > $1.endTime }
        let preferred = stats?.preferredRating
        let snapshot = PlayerSnapshot(
            username: profile.username,
            displayName: profile.name,
            avatarURL: profile.avatar,
            rating: preferred?.0,
            ratingLabel: preferred?.1
        )
        return (snapshot, imported)
    }

    private func resultText(from result: String) -> String {
        if result == "win" { return "Win" }
        let draws: Set<String> = ["agreed", "repetition", "stalemate", "insufficient", "timevsinsufficient", "50move"]
        return draws.contains(result) ? "Draw" : "Loss"
    }

    private func requestJSON<T: Decodable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("ChessCoach/2.0 (github.com/sohailzmn/ui)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw HTTPError(statusCode: http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }
}

struct HTTPError: Error {
    let statusCode: Int
}

// MARK: - Local Stockfish review

final class StockfishSession {
    private var engine: SFEngine?
    private let continuation: AsyncStream<String>.Continuation
    private var iterator: AsyncStream<String>.Iterator

    init(networkURL: URL) {
        var captured: AsyncStream<String>.Continuation!
        let stream = AsyncStream<String> { continuation in
            captured = continuation
        }
        self.continuation = captured
        self.iterator = stream.makeAsyncIterator()

        self.engine = SFEngine(networkFileURL: networkURL) { [weak self] line in
            self?.continuation.yield(line)
        }
    }

    func start() async throws {
        guard let engine else { throw ChessCoachError.engineStopped }
        engine.start()
        engine.sendCommand("uci")
        try await waitForExact("uciok")
        engine.sendCommand("setoption name Threads value 2")
        engine.sendCommand("setoption name Hash value 96")
        engine.sendCommand("setoption name MultiPV value 2")
        engine.sendCommand("setoption name UCI_AnalyseMode value true")
        engine.sendCommand("isready")
        try await waitForExact("readyok")
    }

    func analyze(fen: String, moveTimeMilliseconds: Int) async throws -> EngineAnalysis {
        guard let engine else { throw ChessCoachError.engineStopped }

        engine.sendCommand("position fen \(fen)")
        engine.sendCommand("go movetime \(moveTimeMilliseconds)")

        var evaluations: [Int: Int] = [:]
        var variations: [Int: [String]] = [:]
        let whiteToMove = fen.split(separator: " ").dropFirst().first == "w"

        while let line = await iterator.next() {
            if line.contains("StockfishEmbedded error") {
                throw ChessCoachError.engineFailure(line)
            }

            if line.hasPrefix("info "),
               let parsed = parseInfo(line, whiteToMove: whiteToMove) {
                evaluations[parsed.multiPV] = parsed.evaluation
                if !parsed.pv.isEmpty {
                    variations[parsed.multiPV] = parsed.pv
                }
            }

            if line.hasPrefix("bestmove ") {
                let parts = line.split(separator: " ")
                let best = parts.count > 1 ? String(parts[1]) : ""
                let primaryPV = variations[1] ?? []
                let secondaryPV = variations[2] ?? []

                return EngineAnalysis(
                    evaluation: evaluations[1] ?? 0,
                    bestMove: best == "(none)" ? (primaryPV.first ?? "") : best,
                    principalVariation: primaryPV,
                    secondBestEvaluation: evaluations[2],
                    secondBestMove: secondaryPV.first
                )
            }
        }

        throw ChessCoachError.engineStopped
    }

    func stop() {
        engine?.stop()
        engine = nil
        continuation.finish()
    }

    private func waitForExact(_ target: String) async throws {
        while let line = await iterator.next() {
            if line.contains("StockfishEmbedded error") {
                throw ChessCoachError.engineFailure(line)
            }
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == target {
                return
            }
        }
        throw ChessCoachError.engineStopped
    }

    private func parseInfo(_ line: String, whiteToMove: Bool) -> (multiPV: Int, evaluation: Int, pv: [String])? {
        let tokens = line.split(separator: " ").map(String.init)
        guard let scoreIndex = tokens.firstIndex(of: "score"), scoreIndex + 2 < tokens.count else {
            return nil
        }

        let scoreType = tokens[scoreIndex + 1]
        guard let value = Int(tokens[scoreIndex + 2]) else { return nil }

        var raw: Int
        if scoreType == "cp" {
            raw = value
        } else if scoreType == "mate" {
            let magnitude = max(90_000, 100_000 - abs(value) * 100)
            raw = value >= 0 ? magnitude : -magnitude
        } else {
            return nil
        }

        let whitePositive = whiteToMove ? raw : -raw
        let multiPV: Int = {
            guard let index = tokens.firstIndex(of: "multipv"), index + 1 < tokens.count else { return 1 }
            return Int(tokens[index + 1]) ?? 1
        }()

        var pv: [String] = []
        if let pvIndex = tokens.firstIndex(of: "pv"), pvIndex + 1 < tokens.count {
            pv = Array(tokens[(pvIndex + 1)...])
        }
        return (multiPV, whitePositive, pv)
    }
}

struct StockfishReviewer {
    private let analysisVersion = 2

    func review(
        game: ImportedGame,
        progress: @escaping (Double, String) async -> Void
    ) async throws -> GameReview {
        guard let networkURL = Bundle.main.url(forResource: SFEngine.defaultNetworkFileName, withExtension: nil) else {
            throw ChessCoachError.missingEngineNetwork
        }

        let session = StockfishSession(networkURL: networkURL)
        try await session.start()
        defer { session.stop() }

        let maxPly = game.uciMoves.count
        let positions = Array(game.fens.prefix(maxPly + 1))
        var analyses: [EngineAnalysis] = []
        analyses.reserveCapacity(positions.count)

        let moveTime = maxPly > 120 ? 90 : (maxPly > 70 ? 115 : 145)

        for (index, fen) in positions.enumerated() {
            let fraction = Double(index) / Double(max(positions.count, 1))
            let phaseText: String
            if fraction < 0.28 {
                phaseText = "Engine liest die Partie"
            } else if fraction < 0.72 {
                phaseText = "Jeder Zug wird bewertet"
            } else {
                phaseText = "Kritische Momente werden geprüft"
            }

            await progress(
                fraction * 0.90,
                "\(phaseText) · \(index + 1)/\(positions.count)"
            )
            analyses.append(try await session.analyze(fen: fen, moveTimeMilliseconds: moveTime))
        }

        var moveReviews: [MoveReview] = []
        var myLosses: [Int] = []
        var myAccuracies: [Double] = []
        var opponentAccuracies: [Double] = []

        for index in 0..<maxPly {
            let before = analyses[index]
            let after = analyses[index + 1]
            let moverIsWhite = index % 2 == 0
            let actualMove = game.uciMoves[index]
            let moverRating = isMyMove(index: index, game: game) ? game.myRating : game.opponentRating

            let rawLoss = moverIsWhite
                ? before.evaluation - after.evaluation
                : after.evaluation - before.evaluation
            let cpLoss = max(0, min(10_000, rawLoss))

            let beforeEP = expectedPoints(
                whiteEvaluation: before.evaluation,
                forWhite: moverIsWhite,
                rating: moverRating
            )
            let afterEP = expectedPoints(
                whiteEvaluation: after.evaluation,
                forWhite: moverIsWhite,
                rating: moverRating
            )
            let expectedLoss = max(0, min(1, beforeEP - afterEP))
            let secondBestGap = secondBestExpectedGap(
                analysis: before,
                moverIsWhite: moverIsWhite,
                rating: moverRating
            )

            let grade = classify(
                ply: index + 1,
                actual: actualMove,
                best: before.bestMove,
                expectedLoss: expectedLoss,
                beforeEP: beforeEP,
                afterEP: afterEP,
                secondBestGap: secondBestGap,
                rating: moverRating,
                fenBefore: positions[index],
                fenAfter: positions[index + 1]
            )

            let moveAccuracy = accuracyForMove(expectedLoss: expectedLoss, grade: grade)
            let copy = CoachNarrator.feedback(
                grade: grade,
                actualMove: actualMove,
                bestMove: before.bestMove,
                fenBefore: positions[index],
                evaluationBefore: before.evaluation,
                evaluationAfter: after.evaluation,
                expectedLoss: expectedLoss
            )

            let review = MoveReview(
                ply: index + 1,
                move: actualMove,
                bestMove: before.bestMove,
                evaluationBefore: before.evaluation,
                evaluationAfter: after.evaluation,
                centipawnLoss: cpLoss,
                grade: grade,
                explanation: copy.explanation,
                fenBefore: positions[index],
                fenAfter: positions[index + 1],
                principalVariation: Array(before.principalVariation.prefix(6)),
                expectedPointLoss: expectedLoss,
                moveAccuracy: moveAccuracy,
                headline: copy.headline,
                coachTip: copy.tip,
                secondBestMove: before.secondBestMove
            )

            moveReviews.append(review)

            if isMyMove(index: index, game: game) {
                myLosses.append(cpLoss)
                myAccuracies.append(moveAccuracy)
            } else {
                opponentAccuracies.append(moveAccuracy)
            }
        }

        await progress(0.94, "Report Card und Training werden erstellt")

        let accuracy = average(myAccuracies)
        let opponentAccuracy = average(opponentAccuracies)
        let averageLoss = myLosses.isEmpty ? 0 : myLosses.reduce(0, +) / myLosses.count
        let myReviews = moveReviews.filter { move in
            let whiteMove = move.ply % 2 == 1
            return (game.myColor == "white" && whiteMove) || (game.myColor == "black" && !whiteMove)
        }

        let opening = phaseAccuracy(.opening, reviews: myReviews)
        let middlegame = phaseAccuracy(.middlegame, reviews: myReviews)
        let endgame = phaseAccuracy(.endgame, reviews: myReviews)
        let lesson = makeLesson(from: myReviews, opening: opening, middlegame: middlegame, endgame: endgame)

        await progress(1, "Review fertig")

        return GameReview(
            createdAt: Date(),
            accuracy: accuracy,
            averageCentipawnLoss: averageLoss,
            moves: moveReviews,
            lesson: lesson,
            opponentAccuracy: opponentAccuracy,
            gameRating: estimatedGameRating(actualRating: game.myRating, accuracy: accuracy),
            opponentGameRating: estimatedGameRating(actualRating: game.opponentRating, accuracy: opponentAccuracy),
            openingName: openingName(from: game.pgn),
            openingAccuracy: opening,
            middlegameAccuracy: middlegame,
            endgameAccuracy: endgame,
            analysisVersion: analysisVersion
        )
    }

    private enum Phase {
        case opening, middlegame, endgame
    }

    private func classify(
        ply: Int,
        actual: String,
        best: String,
        expectedLoss: Double,
        beforeEP: Double,
        afterEP: Double,
        secondBestGap: Double,
        rating: Int,
        fenBefore: String,
        fenAfter: String
    ) -> ReviewGrade {
        let exactBest = !best.isEmpty && actual == best
        let nearlyBest = expectedLoss <= 0.018
        let sacrifice = BoardMath.looksLikePieceSacrifice(
            move: actual,
            fenBefore: fenBefore,
            fenAfter: fenAfter,
            moverRating: rating
        )

        if nearlyBest,
           sacrifice,
           afterEP >= 0.40,
           beforeEP < 0.94 {
            return .brilliant
        }

        let greatGap = rating < 1000 ? 0.075 : (rating < 1800 ? 0.095 : 0.12)
        if nearlyBest,
           (exactBest || expectedLoss < 0.01),
           secondBestGap >= greatGap {
            return .great
        }

        let materialDrop = BoardMath.materialChangeForMover(
            fenBefore: fenBefore,
            fenAfter: fenAfter,
            moverWhite: ply % 2 == 1
        )
        if beforeEP >= 0.70,
           afterEP <= 0.58,
           expectedLoss >= 0.12,
           materialDrop > -120 {
            return .miss
        }

        if ply <= 10, expectedLoss <= 0.018 {
            return .book
        }

        if exactBest && expectedLoss <= 0.01 {
            return .best
        }

        switch expectedLoss {
        case ..<0.02:
            return .excellent
        case ..<0.05:
            return .good
        case ..<0.10:
            return .inaccuracy
        case ..<0.20:
            return .mistake
        default:
            return .blunder
        }
    }

    private func expectedPoints(whiteEvaluation cp: Int, forWhite: Bool, rating: Int) -> Double {
        if cp > 90_000 { return forWhite ? 0.999 : 0.001 }
        if cp < -90_000 { return forWhite ? 0.001 : 0.999 }

        let perspective = Double(forWhite ? cp : -cp)
        let ratingScale = max(250.0, min(430.0, 390.0 - Double(rating - 800) * 0.045))
        return 1.0 / (1.0 + exp(-perspective / ratingScale))
    }

    private func secondBestExpectedGap(analysis: EngineAnalysis, moverIsWhite: Bool, rating: Int) -> Double {
        guard let second = analysis.secondBestEvaluation else { return 0 }
        let bestEP = expectedPoints(whiteEvaluation: analysis.evaluation, forWhite: moverIsWhite, rating: rating)
        let secondEP = expectedPoints(whiteEvaluation: second, forWhite: moverIsWhite, rating: rating)
        return max(0, bestEP - secondEP)
    }

    private func accuracyForMove(expectedLoss: Double, grade: ReviewGrade) -> Double {
        if grade == .book { return 100 }
        let score = 100 * exp(-4.25 * expectedLoss)
        return max(0, min(100, score))
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func estimatedGameRating(actualRating: Int, accuracy: Double) -> Int {
        let baseline = max(54.0, min(87.0, 55.0 + Double(actualRating - 500) * 0.0125))
        let estimate = Double(actualRating) + (accuracy - baseline) * 22.0
        return Int(max(300, min(3200, estimate)).rounded() / 25.0) * 25
    }

    private func isMyMove(index: Int, game: ImportedGame) -> Bool {
        let moverIsWhite = index % 2 == 0
        return (game.myColor == "white" && moverIsWhite) || (game.myColor == "black" && !moverIsWhite)
    }

    private func phaseAccuracy(_ phase: Phase, reviews: [MoveReview]) -> Double? {
        let selected = reviews.filter { review in
            let currentPhase: Phase
            if review.ply <= 20 {
                currentPhase = .opening
            } else if BoardMath.nonPawnMaterial(in: review.fenBefore) <= 2_600 {
                currentPhase = .endgame
            } else {
                currentPhase = .middlegame
            }

            switch (phase, currentPhase) {
            case (.opening, .opening), (.middlegame, .middlegame), (.endgame, .endgame):
                return true
            default:
                return false
            }
        }

        let scores = selected.compactMap(\.moveAccuracy)
        guard !scores.isEmpty else { return nil }
        return average(scores)
    }

    private func makeLesson(
        from reviews: [MoveReview],
        opening: Double?,
        middlegame: Double?,
        endgame: Double?
    ) -> String {
        let blunders = reviews.filter { $0.grade == .blunder }.count
        let mistakes = reviews.filter { $0.grade == .mistake || $0.grade == .miss }.count

        if blunders >= 2 {
            return "Dein größter Hebel: Vor jedem Zug einmal Schachs, Schläge und direkte Drohungen prüfen. Genau diese Positionen landen unten im Fehlertraining."
        }
        if blunders == 1 || mistakes >= 2 {
            return "Du spielst viele gute Züge, aber einzelne Wendepunkte kosten viel. Im Review konzentrieren wir uns deshalb auf die Momente, in denen die Gewinnchance stark gefallen ist."
        }

        let phases: [(String, Double)] = [
            ("Eröffnung", opening ?? 101),
            ("Mittelspiel", middlegame ?? 101),
            ("Endspiel", endgame ?? 101)
        ]
        if let weakest = phases.filter({ $0.1 <= 100 }).min(by: { $0.1 < $1.1 }), weakest.1 < 78 {
            return "Die Partie war insgesamt stabil. Dein klarster Trainingsbereich ist das \(weakest.0) – dort war deine Zuggenauigkeit am niedrigsten."
        }

        return "Sehr saubere Partie. Im geführten Review erklären wir trotzdem jeden Zug kurz, damit du nicht nur siehst, was gut war, sondern warum."
    }

    private func openingName(from pgn: String) -> String? {
        if let opening = tag(named: "Opening", in: pgn), !opening.isEmpty {
            return opening
        }

        guard let ecoURL = tag(named: "ECOUrl", in: pgn),
              let component = ecoURL.split(separator: "/").last else {
            return nil
        }

        let raw = String(component).replacingOccurrences(of: "-", with: " ")
        return raw.removingPercentEncoding ?? raw
    }

    private func tag(named name: String, in pgn: String) -> String? {
        let prefix = "[\(name) \""
        guard let start = pgn.range(of: prefix) else { return nil }
        let remainder = pgn[start.upperBound...]
        guard let end = remainder.firstIndex(of: "\"") else { return nil }
        return String(remainder[..<end])
    }
}

private enum CoachNarrator {
    static func feedback(
        grade: ReviewGrade,
        actualMove: String,
        bestMove: String,
        fenBefore: String,
        evaluationBefore: Int,
        evaluationAfter: Int,
        expectedLoss: Double
    ) -> (headline: String, explanation: String, tip: String) {
        let played = BoardMath.friendlyMove(actualMove, in: fenBefore)
        let best = bestMove.isEmpty ? "eine ruhigere Fortsetzung" : BoardMath.friendlyMove(bestMove, in: fenBefore)
        let reason = BoardMath.simpleReason(for: bestMove, in: fenBefore)
        let swing = Int((expectedLoss * 100).rounded())

        switch grade {
        case .brilliant:
            return (
                "Brilliant – den findet man nicht leicht.",
                "\(played) ist stark, obwohl die Figur dabei angreifbar wirkt. Der Zug hält deine Stellung gut und die naheliegenden Alternativen sind deutlich schwächer.",
                "Merke dir das Muster: Material darfst du geben, wenn du dafür etwas Konkretes bekommst – Angriff, Tempo oder eine gewonnene Stellung."
            )
        case .great:
            return (
                "Das war ein wichtiger Zug.",
                "\(played) war hier fast zwingend. Andere Züge hätten deine Stellung deutlich verschlechtert.",
                "Wenn eine Stellung kritisch aussieht, suche nicht zehn Züge. Finde zuerst die 2–3 Züge, die das konkrete Problem lösen."
            )
        case .best:
            return (
                "Genau richtig.",
                "\(played) ist Stockfishs erste Wahl. \(reason)",
                "Versuche dir nicht nur den Zug zu merken, sondern die Idee dahinter."
            )
        case .excellent:
            return (
                "Sehr stark gespielt.",
                "\(played) ist praktisch genauso gut wie \(best). Der Unterschied ist so klein, dass deine Stellung fast unverändert bleibt.",
                "Hier musst du nichts reparieren. Das war eine gute praktische Entscheidung."
            )
        case .good:
            return (
                "Guter Zug.",
                "\(played) funktioniert. Noch etwas genauer wäre \(best), aber du gibst nur sehr wenig ab.",
                "Gute Züge sind völlig okay. Entscheidend ist, große Fehler zu vermeiden."
            )
        case .book:
            return (
                "Eröffnungstheorie – alles normal.",
                "\(played) hält die Stellung gesund und passt in die Eröffnungsphase.",
                "In der Eröffnung: Figuren raus, König sicher, Zentrum kontrollieren."
            )
        case .inaccuracy:
            return (
                "Kleine Ungenauigkeit.",
                "\(played) gibt ungefähr \(swing)% erwartete Punkte ab. Einfacher wäre \(best). \(reason)",
                "Bevor du einen ruhigen Zug spielst, prüfe kurz, ob du eine aktivere Möglichkeit hast."
            )
        case .mistake:
            return (
                "Hier wird es deutlich schwieriger.",
                "\(played) kostet spürbar Gewinnchance. \(best) hält deine Stellung wesentlich besser. \(reason)",
                "Stopp-Regel: Vor kritischen Zügen erst die stärkste Antwort des Gegners suchen."
            )
        case .miss:
            return (
                "Chance verpasst.",
                "Dein Gegner hat dir hier eine echte Möglichkeit gegeben. \(played) nutzt sie nicht; mit \(best) hättest du deutlich mehr aus der Stellung bekommen.",
                "Nach einem gegnerischen Fehler sofort nach Schachs, Schlägen und direkten Drohungen suchen."
            )
        case .blunder:
            return (
                "Das ist der Wendepunkt.",
                "\(played) verändert die Partie stark zu deinem Nachteil. \(best) verhindert das. \(reason)",
                "Mach vor dem Zug einen 3-Sekunden-Blunder-Check: Was kann der Gegner sofort schlagen, schachgeben oder drohen?"
            )
        }
    }
}

enum BoardMath {
    static func pieces(from fen: String) -> [String: Character] {
        guard let placement = fen.split(separator: " ").first else { return [:] }
        let rows = placement.split(separator: "/")
        guard rows.count == 8 else { return [:] }

        let files = Array("abcdefgh")
        var output: [String: Character] = [:]

        for (rowIndex, row) in rows.enumerated() {
            let rank = 8 - rowIndex
            var fileIndex = 0
            for char in row {
                if let empty = char.wholeNumberValue {
                    fileIndex += empty
                } else if fileIndex < 8 {
                    output["\(files[fileIndex])\(rank)"] = char
                    fileIndex += 1
                }
            }
        }
        return output
    }

    static func nonPawnMaterial(in fen: String) -> Int {
        pieces(from: fen).values.reduce(0) { partial, piece in
            let upper = Character(String(piece).uppercased())
            guard upper != "P", upper != "K" else { return partial }
            return partial + value(of: piece)
        }
    }

    static func materialChangeForMover(fenBefore: String, fenAfter: String, moverWhite: Bool) -> Int {
        let before = materialBalance(in: fenBefore)
        let after = materialBalance(in: fenAfter)
        let delta = after - before
        return moverWhite ? delta : -delta
    }

    static func looksLikePieceSacrifice(move: String, fenBefore: String, fenAfter: String, moverRating: Int) -> Bool {
        let chars = Array(move)
        guard chars.count >= 4 else { return false }
        let from = String(chars[0...1])
        let to = String(chars[2...3])
        let before = pieces(from: fenBefore)
        let after = pieces(from: fenAfter)
        guard let movingPiece = before[from], let landedPiece = after[to] else { return false }

        let movedValue = value(of: movingPiece)
        guard movedValue >= 300 else { return false }

        let moverWhite = movingPiece.isUppercase
        let attackers = attackerValues(of: to, byWhite: !moverWhite, pieces: after)
        guard let cheapest = attackers.min() else { return false }

        let tolerance = moverRating < 1000 ? 80 : (moverRating < 1800 ? 30 : 0)
        return cheapest <= movedValue - 100 + tolerance && value(of: landedPiece) >= 300
    }

    static func friendlyMove(_ move: String, in fen: String) -> String {
        let chars = Array(move)
        guard chars.count >= 4 else { return move }
        let from = String(chars[0...1])
        let to = String(chars[2...3])
        let board = pieces(from: fen)
        guard let piece = board[from] else { return move }

        if Character(String(piece).uppercased()) == "K" {
            if from == "e1" && to == "g1" || from == "e8" && to == "g8" { return "kurze Rochade" }
            if from == "e1" && to == "c1" || from == "e8" && to == "c8" { return "lange Rochade" }
        }

        let capture = board[to] != nil
        let separator = capture ? "×" : "–"
        return "\(pieceName(piece)) \(from)\(separator)\(to)"
    }

    static func simpleReason(for move: String, in fen: String) -> String {
        let chars = Array(move)
        guard chars.count >= 4 else { return "Der Zug hält deine Stellung zusammen." }
        let from = String(chars[0...1])
        let to = String(chars[2...3])
        let board = pieces(from: fen)
        guard let piece = board[from] else { return "Der Zug hält deine Stellung zusammen." }

        if let captured = board[to] {
            return "Du nimmst damit \(pieceName(captured).lowercased()) und verbesserst gleichzeitig deine Stellung."
        }

        let upper = Character(String(piece).uppercased())
        if upper == "K", (from.hasPrefix("e") && (to.hasPrefix("g") || to.hasPrefix("c"))) {
            return "Dein König wird sicherer und deine Türme kommen ins Spiel."
        }

        if ["d4", "d5", "e4", "e5"].contains(to) {
            return "Du kontrollierst damit wichtige Felder im Zentrum."
        }

        switch upper {
        case "N", "B":
            return "Die Figur wird aktiver und bekommt mehr Einfluss."
        case "R":
            return "Der Turm bekommt eine aktivere Linie."
        case "Q":
            return "Die Dame erhöht den Druck, ohne unnötig Material zu riskieren."
        case "P":
            return "Der Bauernzug verbessert deine Struktur oder gewinnt Raum."
        default:
            return "Der Zug hält deine Stellung zusammen und lässt dem Gegner weniger Gegenspiel."
        }
    }

    private static func materialBalance(in fen: String) -> Int {
        pieces(from: fen).values.reduce(0) { partial, piece in
            let signed = piece.isUppercase ? value(of: piece) : -value(of: piece)
            return partial + signed
        }
    }

    private static func value(of piece: Character) -> Int {
        switch Character(String(piece).uppercased()) {
        case "P": return 100
        case "N": return 320
        case "B": return 330
        case "R": return 500
        case "Q": return 900
        case "K": return 10_000
        default: return 0
        }
    }

    private static func pieceName(_ piece: Character) -> String {
        switch Character(String(piece).uppercased()) {
        case "P": return "Bauer"
        case "N": return "Springer"
        case "B": return "Läufer"
        case "R": return "Turm"
        case "Q": return "Dame"
        case "K": return "König"
        default: return "Figur"
        }
    }

    private static func attackerValues(of target: String, byWhite: Bool, pieces: [String: Character]) -> [Int] {
        guard let targetCoord = coord(target) else { return [] }
        var values: [Int] = []

        for (square, piece) in pieces {
            guard piece.isUppercase == byWhite, let from = coord(square) else { continue }
            if attacks(piece: piece, from: from, to: targetCoord, pieces: pieces) {
                values.append(value(of: piece))
            }
        }
        return values
    }

    private static func attacks(
        piece: Character,
        from: (Int, Int),
        to: (Int, Int),
        pieces: [String: Character]
    ) -> Bool {
        let dx = to.0 - from.0
        let dy = to.1 - from.1
        let upper = Character(String(piece).uppercased())

        switch upper {
        case "P":
            let direction = piece.isUppercase ? 1 : -1
            return dy == direction && abs(dx) == 1
        case "N":
            return (abs(dx), abs(dy)) == (1, 2) || (abs(dx), abs(dy)) == (2, 1)
        case "K":
            return max(abs(dx), abs(dy)) == 1
        case "B":
            guard abs(dx) == abs(dy), dx != 0 else { return false }
            return pathClear(from: from, to: to, pieces: pieces)
        case "R":
            guard (dx == 0) != (dy == 0) else { return false }
            return pathClear(from: from, to: to, pieces: pieces)
        case "Q":
            let straight = (dx == 0) != (dy == 0)
            let diagonal = abs(dx) == abs(dy) && dx != 0
            guard straight || diagonal else { return false }
            return pathClear(from: from, to: to, pieces: pieces)
        default:
            return false
        }
    }

    private static func pathClear(from: (Int, Int), to: (Int, Int), pieces: [String: Character]) -> Bool {
        let stepX = (to.0 - from.0).signum()
        let stepY = (to.1 - from.1).signum()
        var x = from.0 + stepX
        var y = from.1 + stepY

        while (x, y) != to {
            if pieces[square(x: x, y: y)] != nil { return false }
            x += stepX
            y += stepY
        }
        return true
    }

    private static func coord(_ square: String) -> (Int, Int)? {
        let chars = Array(square)
        guard chars.count == 2,
              let ascii = chars[0].asciiValue,
              let rank = chars[1].wholeNumberValue else { return nil }
        return (Int(ascii) - 97, rank)
    }

    private static func square(x: Int, y: Int) -> String {
        guard let scalar = UnicodeScalar(97 + x) else { return "" }
        return "\(Character(scalar))\(y)"
    }
}
