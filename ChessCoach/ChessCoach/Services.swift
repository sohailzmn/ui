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
        request.setValue("ChessCoach/1.0 (github.com/sohailzmn/ui)", forHTTPHeaderField: "User-Agent")
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
        engine.sendCommand("setoption name Hash value 64")
        engine.sendCommand("setoption name UCI_AnalyseMode value true")
        engine.sendCommand("isready")
        try await waitForExact("readyok")
    }

    func analyze(fen: String, moveTimeMilliseconds: Int) async throws -> EngineAnalysis {
        guard let engine else { throw ChessCoachError.engineStopped }

        engine.sendCommand("position fen \(fen)")
        engine.sendCommand("go movetime \(moveTimeMilliseconds)")

        var latestEvaluation = 0
        var principalVariation: [String] = []
        let whiteToMove = fen.split(separator: " ").dropFirst().first == "w"

        while let line = await iterator.next() {
            if line.contains("StockfishEmbedded error") {
                throw ChessCoachError.engineFailure(line)
            }

            if line.hasPrefix("info ") {
                if let parsed = parseInfo(line, whiteToMove: whiteToMove) {
                    latestEvaluation = parsed.evaluation
                    if !parsed.pv.isEmpty {
                        principalVariation = parsed.pv
                    }
                }
            }

            if line.hasPrefix("bestmove ") {
                let parts = line.split(separator: " ")
                let best = parts.count > 1 ? String(parts[1]) : ""
                return EngineAnalysis(
                    evaluation: latestEvaluation,
                    bestMove: best == "(none)" ? "" : best,
                    principalVariation: principalVariation
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

    private func parseInfo(_ line: String, whiteToMove: Bool) -> (evaluation: Int, pv: [String])? {
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
        var pv: [String] = []
        if let pvIndex = tokens.firstIndex(of: "pv"), pvIndex + 1 < tokens.count {
            pv = Array(tokens[(pvIndex + 1)...])
        }
        return (whitePositive, pv)
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

        let maxPly = min(game.uciMoves.count, 120)
        let positions = Array(game.fens.prefix(maxPly + 1))
        var analyses: [EngineAnalysis] = []
        analyses.reserveCapacity(positions.count)

        for (index, fen) in positions.enumerated() {
            let fraction = Double(index) / Double(max(positions.count, 1))
            await progress(fraction * 0.88, "Position \(index + 1) von \(positions.count) wird analysiert")
            analyses.append(try await session.analyze(fen: fen, moveTimeMilliseconds: 180))
        }

        var moveReviews: [MoveReview] = []
        var myLosses: [Int] = []

        for index in 0..<maxPly {
            let before = analyses[index]
            let after = analyses[index + 1]
            let moverIsWhite = index % 2 == 0
            let actualMove = game.uciMoves[index]

            let rawLoss = moverIsWhite
                ? before.evaluation - after.evaluation
                : after.evaluation - before.evaluation
            let cpLoss = max(0, min(10_000, rawLoss))
            let grade = gradeFor(loss: cpLoss, actual: actualMove, best: before.bestMove)
            let isMyMove = (game.myColor == "white" && moverIsWhite) || (game.myColor == "black" && !moverIsWhite)
            if isMyMove { myLosses.append(cpLoss) }

            let explanation = explanationFor(
                grade: grade,
                loss: cpLoss,
                actual: actualMove,
                best: before.bestMove,
                evaluationBefore: before.evaluation,
                evaluationAfter: after.evaluation
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
                    explanation: explanation,
                    fenBefore: positions[index],
                    fenAfter: positions[index + 1],
                    principalVariation: Array(before.principalVariation.prefix(6))
                )
            )
        }

        await progress(0.94, "Deine Lernschwerpunkte werden erstellt")

        let averageLoss = myLosses.isEmpty ? 0 : myLosses.reduce(0, +) / myLosses.count
        let accuracy = max(0, min(100, 100 * exp(-Double(averageLoss) / 600.0)))
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
            lesson: lesson
        )
    }

    private func gradeFor(loss: Int, actual: String, best: String) -> ReviewGrade {
        if !best.isEmpty && actual == best { return .best }
        switch loss {
        case ...15: return .best
        case ...40: return .great
        case ...90: return .inaccuracy
        case ...180: return .mistake
        default: return .blunder
        }
    }

    private func explanationFor(
        grade: ReviewGrade,
        loss: Int,
        actual: String,
        best: String,
        evaluationBefore: Int,
        evaluationAfter: Int
    ) -> String {
        let pawnLoss = String(format: "%.1f", Double(loss) / 100.0)
        let bestText = best.isEmpty ? "keinen klaren Alternativzug" : best

        switch grade {
        case .best:
            return actual == best
                ? "Du hast den stärksten Engine-Zug gefunden. Prüfe trotzdem, welche Drohung oder Verbesserung hinter \(actual) steckt."
                : "Der Zug hält die Stellung praktisch stabil. Stockfish bevorzugt \(bestText) nur geringfügig."
        case .great:
            return "Solider Zug. Du gibst nur ungefähr \(pawnLoss) Bauerneinheiten gegenüber der Engine-Wahl \(bestText) ab."
        case .inaccuracy:
            return "Hier wird die Stellung etwas schwieriger. Vergleiche \(actual) mit \(bestText) und suche nach Tempo, Entwicklung oder Königssicherheit."
        case .mistake:
            return "Dieser Zug kostet ungefähr \(pawnLoss) Bauerneinheiten. Vor dem Zug war die Bewertung \(formatEval(evaluationBefore)), danach \(formatEval(evaluationAfter)). Besser war \(bestText)."
        case .blunder:
            return "Großer Bewertungswechsel: etwa \(pawnLoss) Bauerneinheiten gehen verloren. Stoppe hier und rechne zuerst Checks, Captures und Threats. Stockfish bevorzugt \(bestText)."
        }
    }

    private func makeLesson(from reviews: [MoveReview]) -> String {
        let blunders = reviews.filter { $0.grade == .blunder }.count
        let mistakes = reviews.filter { $0.grade == .mistake }.count
        let inaccuracies = reviews.filter { $0.grade == .inaccuracy }.count

        if blunders >= 2 {
            return "Dein größter Hebel ist Blunder-Check: Vor jedem Zug kurz gegnerische Schachs, Schläge und direkte Drohungen prüfen."
        }
        if blunders == 1 || mistakes >= 2 {
            return "Nimm dir an kritischen Stellen mehr Zeit. Suche mindestens zwei Kandidatenzüge und vergleiche die gegnerische stärkste Antwort."
        }
        if inaccuracies >= 3 {
            return "Die Partie war taktisch stabil. Arbeite jetzt an kleinen Stellungsverbesserungen: Figurenaktivität, Bauernhebel und schlechte Figuren."
        }
        return "Sehr stabile Partie. Wiederhole die wenigen Abweichungen und versuche, die Idee hinter dem Engine-Zug in eigenen Worten zu erklären."
    }

    private func formatEval(_ cp: Int) -> String {
        if abs(cp) > 90_000 { return cp > 0 ? "Gewinnstellung für Weiß" : "Gewinnstellung für Schwarz" }
        return String(format: "%+.2f", Double(cp) / 100.0)
    }
}
