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

        let maxPly = min(game.uciMoves.count, 140)
        let positions = Array(game.fens.prefix(maxPly + 1))
        var analyses: [EngineAnalysis] = []
        analyses.reserveCapacity(positions.count)

        for (index, fen) in positions.enumerated() {
            let fraction = Double(index) / Double(max(positions.count, 1))
            await progress(fraction * 0.82, "Stockfish prüft Zug \(index + 1) von \(positions.count)")
            analyses.append(try await session.analyze(fen: fen, moveTimeMilliseconds: 150))
        }

        var moveReviews: [MoveReview] = []
        var myLosses: [Int] = []
        var myExpectedLosses: [Double] = []

        for index in 0..<maxPly {
            let before = analyses[index]
            let after = analyses[index + 1]
            let moverIsWhite = index % 2 == 0
            let actualMove = game.uciMoves[index]
            let isMyMove = (game.myColor == "white" && moverIsWhite) || (game.myColor == "black" && !moverIsWhite)

            let rawLoss = moverIsWhite
                ? before.evaluation - after.evaluation
                : after.evaluation - before.evaluation
            let cpLoss = max(0, min(10_000, rawLoss))

            let beforePoints = expectedPoints(
                whiteEvaluation: before.evaluation,
                moverIsWhite: moverIsWhite,
                rating: isMyMove ? game.myRating : game.opponentRating
            )
            let afterPoints = expectedPoints(
                whiteEvaluation: after.evaluation,
                moverIsWhite: moverIsWhite,
                rating: isMyMove ? game.myRating : game.opponentRating
            )
            let pointsLost = max(0, min(1, beforePoints - afterPoints))

            var grade = classification(
                expectedPointsLost: pointsLost,
                actual: actualMove,
                best: before.bestMove
            )

            let brilliant = isBrilliant(
                actual: actualMove,
                analysis: before,
                fenBefore: positions[index],
                expectedBefore: beforePoints,
                expectedAfter: afterPoints
            )
            let missed = isMiss(expectedBefore: beforePoints, expectedAfter: afterPoints, pointsLost: pointsLost)
            let great = isGreat(
                actual: actualMove,
                best: before.bestMove,
                expectedBefore: beforePoints,
                expectedAfter: afterPoints,
                pointsLost: pointsLost,
                ply: index + 1
            )

            if brilliant {
                grade = .brilliant
            } else if missed {
                grade = .miss
            } else if great {
                grade = .great
            } else if index < 10 && pointsLost <= 0.006 && (actualMove == before.bestMove || grade == .excellent) {
                grade = .book
            }

            if isMyMove {
                myLosses.append(cpLoss)
                myExpectedLosses.append(pointsLost)
            }

            let copy = coachCopy(
                grade: grade,
                actual: actualMove,
                best: before.bestMove,
                pointsLost: pointsLost,
                evaluationBefore: before.evaluation,
                evaluationAfter: after.evaluation,
                pv: before.principalVariation
            )

            moveReviews.append(
                MoveReview(
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
                    principalVariation: Array(before.principalVariation.prefix(8)),
                    expectedPointsLoss: pointsLost,
                    coachTitle: copy.title,
                    isKeyMoment: isKeyMoment(grade)
                )
            )
        }

        await progress(0.88, "Coach-Erklärungen werden vereinfacht")

        // Deepen the most important positions. This keeps normal reviews fast while
        // giving mistakes, misses and blunders a stronger best-move/PV suggestion.
        let criticalIndices = moveReviews.enumerated()
            .filter { isKeyMoment($0.element.grade) }
            .sorted { ($0.element.expectedPointsLoss ?? 0) > ($1.element.expectedPointsLoss ?? 0) }
            .prefix(8)
            .map(\.offset)

        for (offset, index) in criticalIndices.enumerated() {
            let fraction = 0.88 + (Double(offset + 1) / Double(max(criticalIndices.count, 1))) * 0.08
            await progress(fraction, "Kritische Positionen werden tiefer geprüft")
            let deep = try await session.analyze(fen: positions[index], moveTimeMilliseconds: 480)
            let old = moveReviews[index]
            let copy = coachCopy(
                grade: old.grade,
                actual: old.move,
                best: deep.bestMove,
                pointsLost: old.expectedPointsLoss ?? 0,
                evaluationBefore: deep.evaluation,
                evaluationAfter: old.evaluationAfter,
                pv: deep.principalVariation
            )
            moveReviews[index] = MoveReview(
                ply: old.ply,
                move: old.move,
                bestMove: deep.bestMove.isEmpty ? old.bestMove : deep.bestMove,
                evaluationBefore: deep.evaluation,
                evaluationAfter: old.evaluationAfter,
                centipawnLoss: old.centipawnLoss,
                grade: old.grade,
                explanation: copy.explanation,
                fenBefore: old.fenBefore,
                fenAfter: old.fenAfter,
                principalVariation: Array(deep.principalVariation.prefix(8)),
                expectedPointsLoss: old.expectedPointsLoss,
                coachTitle: copy.title,
                isKeyMoment: old.isKeyMoment
            )
        }

        await progress(0.97, "Report Card wird erstellt")

        let averageLoss = myLosses.isEmpty ? 0 : myLosses.reduce(0, +) / myLosses.count
        let accuracy = accuracyScore(from: myExpectedLosses)
        let performance = performanceRating(
            accuracy: accuracy,
            playerRating: game.myRating,
            opponentRating: game.opponentRating
        )
        let myReviews = moveReviews.filter {
            let whiteMove = $0.ply % 2 == 1
            return (game.myColor == "white" && whiteMove) || (game.myColor == "black" && !whiteMove)
        }
        let lesson = makeLesson(from: myReviews)

        await progress(1, "Review fertig")

        return GameReview(
            createdAt: Date(),
            accuracy: accuracy,
            averageCentipawnLoss: averageLoss,
            moves: moveReviews,
            lesson: lesson,
            performanceRating: performance,
            evaluationSeries: analyses.map(\.evaluation)
        )
    }

    // Chess.com's current public Classification V2 cutoffs are based on Expected
    // Points lost. We use the same published bands with our own local conversion
    // from Stockfish centipawns to expected outcome.
    private func classification(expectedPointsLost loss: Double, actual: String, best: String) -> ReviewGrade {
        if !best.isEmpty && actual == best { return .best }
        switch loss {
        case ...0.02: return .excellent
        case ...0.05: return .good
        case ...0.10: return .inaccuracy
        case ...0.20: return .mistake
        default: return .blunder
        }
    }

    private func expectedPoints(whiteEvaluation cp: Int, moverIsWhite: Bool, rating: Int) -> Double {
        if cp > 90_000 { return moverIsWhite ? 1 : 0 }
        if cp < -90_000 { return moverIsWhite ? 0 : 1 }

        let boundedRating = min(2600, max(400, rating))
        let scale = 315.0 - Double(boundedRating - 400) * 0.0375
        let white = 1.0 / (1.0 + exp(-Double(cp) / max(205, scale)))
        return moverIsWhite ? white : 1 - white
    }

    private func accuracyScore(from losses: [Double]) -> Double {
        guard !losses.isEmpty else { return 100 }
        // Human-readable 0...100 score: perfect moves stay at 100 while errors
        // become increasingly expensive. One blunder hurts without making the
        // entire game look like a zero.
        let qualities = losses.map { exp(-5.3 * min(0.65, $0)) }
        let raw = 100 * qualities.reduce(0, +) / Double(qualities.count)
        return min(100, max(0, raw))
    }

    private func performanceRating(accuracy: Double, playerRating: Int, opponentRating: Int) -> Int {
        let expectedAccuracy = min(91.0, max(56.0, 50.0 + Double(playerRating) * 0.018))
        let qualityDelta = Int(((accuracy - expectedAccuracy) * 21.0).rounded())
        let opponentAdjustment = Int((Double(opponentRating - playerRating) * 0.12).rounded())
        return min(3200, max(100, playerRating + qualityDelta + opponentAdjustment))
    }

    private func isBrilliant(
        actual: String,
        analysis: EngineAnalysis,
        fenBefore: String,
        expectedBefore: Double,
        expectedAfter: Double
    ) -> Bool {
        guard actual == analysis.bestMove,
              expectedAfter >= 0.48,
              expectedBefore < 0.94,
              analysis.principalVariation.count >= 2,
              actual.count >= 4 else { return false }

        let moveChars = Array(actual)
        let destination = String(moveChars[2...3])
        let reply = analysis.principalVariation[1]
        guard reply.count >= 4 else { return false }
        let replyChars = Array(reply)
        let replyDestination = String(replyChars[2...3])

        // A practical local sacrifice heuristic: Stockfish's best line allows the
        // moved non-pawn piece to be taken immediately and still prefers the move.
        guard replyDestination == destination,
              let piece = pieceAt(square: String(moveChars[0...1]), fen: fenBefore) else { return false }
        return piece.lowercased() != "p"
    }

    private func isGreat(
        actual: String,
        best: String,
        expectedBefore: Double,
        expectedAfter: Double,
        pointsLost: Double,
        ply: Int
    ) -> Bool {
        guard actual == best, pointsLost <= 0.004, ply > 8 else { return false }
        // Reserve Great for genuinely critical positions rather than every best move.
        return (expectedBefore >= 0.28 && expectedBefore <= 0.62 && expectedAfter >= 0.27)
            || (expectedBefore >= 0.62 && expectedBefore <= 0.82 && expectedAfter >= 0.61)
    }

    private func isMiss(expectedBefore: Double, expectedAfter: Double, pointsLost: Double) -> Bool {
        expectedBefore >= 0.72 && expectedAfter <= 0.57 && pointsLost >= 0.13
    }

    private func isKeyMoment(_ grade: ReviewGrade) -> Bool {
        switch grade {
        case .brilliant, .great, .inaccuracy, .mistake, .miss, .blunder: return true
        default: return false
        }
    }

    private func coachCopy(
        grade: ReviewGrade,
        actual: String,
        best: String,
        pointsLost: Double,
        evaluationBefore: Int,
        evaluationAfter: Int,
        pv: [String]
    ) -> (title: String, explanation: String) {
        let bestText = best.isEmpty ? "der ruhigere Zug" : best
        switch grade {
        case .brilliant:
            return ("Brillant! Genau diese Idee war schwer zu sehen.",
                    "Du lässt Material zu, bekommst dafür aber die stärkere Stellung. \(bestText) funktioniert, weil die folgende Taktik für dich aufgeht.")
        case .great:
            return ("Sehr stark – das war ein Schlüsselzug.",
                    "In dieser schwierigen Stellung hält \(actual) alles zusammen. Ein anderer Zug hätte deine Chancen deutlich verschlechtert.")
        case .best:
            return ("Genau richtig.",
                    "\(actual) ist Stockfishs erste Wahl. Du verbesserst deine Stellung, ohne dem Gegner etwas zu schenken.")
        case .excellent:
            return ("Fast perfekt.",
                    "Dein Zug ist sehr gut. \(bestText) ist nur ein kleines bisschen genauer – praktisch bleibst du auf Kurs.")
        case .good:
            return ("Solide gespielt.",
                    "Kein echter Fehler. Mit \(bestText) hättest du etwas mehr Druck behalten.")
        case .book:
            return ("Sauber aus der Eröffnung.",
                    "Das ist ein natürlicher Eröffnungszug: entwickeln, Zentrum kontrollieren und den König sicher bekommen.")
        case .inaccuracy:
            return ("Kleine Ungenauigkeit.",
                    "\(bestText) war einfacher und hält mehr Druck. Dein Zug ist spielbar, macht die Stellung aber unnötig schwerer.")
        case .mistake:
            return ("Hier wird es deutlich schwerer.",
                    "\(bestText) hätte deine Stellung zusammengehalten. Nach \(actual) bekommt der Gegner eine klare Chance.")
        case .miss:
            return ("Hier hast du eine Chance liegen lassen.",
                    "Du konntest die Partie mit \(bestText) deutlich zu deinen Gunsten drehen. Das war der Moment, genauer zu rechnen.")
        case .blunder:
            return ("Hier kippt die Partie.",
                    "\(bestText) verhindert den großen Schaden. Nach \(actual) kann der Gegner sofort einen entscheidenden Vorteil bekommen.")
        }
    }

    private func makeLesson(from reviews: [MoveReview]) -> String {
        let blunders = reviews.filter { $0.grade == .blunder }.count
        let misses = reviews.filter { $0.grade == .miss }.count
        let mistakes = reviews.filter { $0.grade == .mistake }.count
        let inaccuracies = reviews.filter { $0.grade == .inaccuracy }.count

        if blunders >= 2 {
            return "Dein größter Hebel: vor jedem Zug kurz Schachs, Schläge und direkte Drohungen des Gegners prüfen."
        }
        if blunders == 1 {
            return "Eine einzige kritische Stelle hat viel entschieden. Trainiere genau diese Position noch einmal."
        }
        if misses >= 1 {
            return "Du hast eine gute Chance nicht genutzt. Suche in starken Stellungen zuerst nach forcing moves: Schach, Schlag, Drohung."
        }
        if mistakes >= 2 {
            return "Nimm dir an kritischen Stellen mehr Zeit und vergleiche mindestens zwei Kandidatenzüge."
        }
        if inaccuracies >= 3 {
            return "Taktisch war die Partie stabil. Dein nächster Schritt sind kleine Verbesserungen bei Aktivität und Figurenstellung."
        }
        return "Sehr stabile Partie. Wiederhole die wenigen Abweichungen und erkläre dir die Idee hinter dem besten Zug selbst."
    }

    private func pieceAt(square: String, fen: String) -> String? {
        guard square.count == 2,
              let placement = fen.split(separator: " ").first else { return nil }
        let chars = Array(square)
        guard let fileASCII = chars[0].asciiValue,
              let rank = chars[1].wholeNumberValue else { return nil }
        let wantedFile = Int(fileASCII) - 97
        let wantedRow = 8 - rank
        let rows = placement.split(separator: "/")
        guard wantedRow >= 0, wantedRow < rows.count else { return nil }

        var file = 0
        for char in rows[wantedRow] {
            if let empty = char.wholeNumberValue {
                file += empty
            } else {
                if file == wantedFile { return String(char) }
                file += 1
            }
        }
        return nil
    }
}
