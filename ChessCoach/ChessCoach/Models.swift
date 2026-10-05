import Foundation

struct ImportedGame: Identifiable, Codable {
    let id: String
    let chessComURL: String
    let pgn: String
    let opponent: String
    let opponentRating: Int
    let myRating: Int
    let myColor: String
    let result: String
    let timeClass: String
    let endTime: Date
    let uciMoves: [String]
    let fens: [String]
    var review: GameReview?

    var moveCount: Int { uciMoves.count }

    var resultSymbol: String {
        switch result {
        case "Win": return "checkmark.circle.fill"
        case "Draw": return "minus.circle.fill"
        default: return "xmark.circle.fill"
        }
    }
}

struct GameReview: Codable {
    let createdAt: Date
    let accuracy: Double
    let averageCentipawnLoss: Int
    let moves: [MoveReview]
    let lesson: String

    let opponentAccuracy: Double?
    let gameRating: Int?
    let opponentGameRating: Int?
    let openingName: String?
    let openingAccuracy: Double?
    let middlegameAccuracy: Double?
    let endgameAccuracy: Double?
    let analysisVersion: Int?

    init(
        createdAt: Date,
        accuracy: Double,
        averageCentipawnLoss: Int,
        moves: [MoveReview],
        lesson: String,
        opponentAccuracy: Double? = nil,
        gameRating: Int? = nil,
        opponentGameRating: Int? = nil,
        openingName: String? = nil,
        openingAccuracy: Double? = nil,
        middlegameAccuracy: Double? = nil,
        endgameAccuracy: Double? = nil,
        analysisVersion: Int? = nil
    ) {
        self.createdAt = createdAt
        self.accuracy = accuracy
        self.averageCentipawnLoss = averageCentipawnLoss
        self.moves = moves
        self.lesson = lesson
        self.opponentAccuracy = opponentAccuracy
        self.gameRating = gameRating
        self.opponentGameRating = opponentGameRating
        self.openingName = openingName
        self.openingAccuracy = openingAccuracy
        self.middlegameAccuracy = middlegameAccuracy
        self.endgameAccuracy = endgameAccuracy
        self.analysisVersion = analysisVersion
    }

    var isModernReview: Bool { analysisVersion == 2 }

    func count(_ grade: ReviewGrade, forWhite: Bool? = nil) -> Int {
        moves.filter { move in
            let colorMatches = forWhite.map { $0 == (move.ply % 2 == 1) } ?? true
            return colorMatches && move.grade == grade
        }.count
    }

    var blunderCount: Int { count(.blunder) }
    var mistakeCount: Int { count(.mistake) }
    var inaccuracyCount: Int { count(.inaccuracy) }
}

struct MoveReview: Identifiable, Codable {
    var id: Int { ply }

    let ply: Int
    let move: String
    let bestMove: String
    let evaluationBefore: Int
    let evaluationAfter: Int
    let centipawnLoss: Int
    let grade: ReviewGrade
    let explanation: String
    let fenBefore: String
    let fenAfter: String
    let principalVariation: [String]

    let expectedPointLoss: Double?
    let moveAccuracy: Double?
    let headline: String?
    let coachTip: String?
    let secondBestMove: String?

    init(
        ply: Int,
        move: String,
        bestMove: String,
        evaluationBefore: Int,
        evaluationAfter: Int,
        centipawnLoss: Int,
        grade: ReviewGrade,
        explanation: String,
        fenBefore: String,
        fenAfter: String,
        principalVariation: [String],
        expectedPointLoss: Double? = nil,
        moveAccuracy: Double? = nil,
        headline: String? = nil,
        coachTip: String? = nil,
        secondBestMove: String? = nil
    ) {
        self.ply = ply
        self.move = move
        self.bestMove = bestMove
        self.evaluationBefore = evaluationBefore
        self.evaluationAfter = evaluationAfter
        self.centipawnLoss = centipawnLoss
        self.grade = grade
        self.explanation = explanation
        self.fenBefore = fenBefore
        self.fenAfter = fenAfter
        self.principalVariation = principalVariation
        self.expectedPointLoss = expectedPointLoss
        self.moveAccuracy = moveAccuracy
        self.headline = headline
        self.coachTip = coachTip
        self.secondBestMove = secondBestMove
    }

    var moveNumberText: String {
        let number = (ply + 1) / 2
        return ply % 2 == 1 ? "\(number)." : "\(number)..."
    }
}

enum ReviewGrade: String, Codable, CaseIterable {
    case brilliant = "Brilliant"
    case great = "Great"
    case best = "Best"
    case excellent = "Excellent"
    case good = "Good"
    case book = "Book"
    case inaccuracy = "Inaccuracy"
    case mistake = "Mistake"
    case miss = "Miss"
    case blunder = "Blunder"

    var symbol: String {
        switch self {
        case .brilliant: return "diamond.fill"
        case .great: return "exclamationmark.circle.fill"
        case .best: return "star.fill"
        case .excellent: return "checkmark.seal.fill"
        case .good: return "checkmark.circle.fill"
        case .book: return "book.closed.fill"
        case .inaccuracy: return "questionmark.circle.fill"
        case .mistake: return "exclamationmark.triangle.fill"
        case .miss: return "scope"
        case .blunder: return "xmark.octagon.fill"
        }
    }

    var shortLabel: String {
        switch self {
        case .brilliant: return "!!"
        case .great: return "!"
        case .best: return "★"
        case .excellent: return "✓+"
        case .good: return "✓"
        case .book: return "Book"
        case .inaccuracy: return "?!"
        case .mistake: return "?"
        case .miss: return "Miss"
        case .blunder: return "??"
        }
    }

    var isCritical: Bool {
        switch self {
        case .brilliant, .great, .inaccuracy, .mistake, .miss, .blunder:
            return true
        case .best, .excellent, .good, .book:
            return false
        }
    }

    var isTrainingCandidate: Bool {
        switch self {
        case .inaccuracy, .mistake, .miss, .blunder:
            return true
        default:
            return false
        }
    }
}

struct TrainingPuzzle: Identifiable {
    let id: String
    let gameID: String
    let opponent: String
    let ply: Int
    let fen: String
    let bestMove: String
    let playedMove: String
    let grade: ReviewGrade
    let explanation: String
    let whiteToMove: Bool
}

struct PlayerSnapshot: Codable {
    let username: String
    let displayName: String?
    let avatarURL: String?
    let rating: Int?
    let ratingLabel: String?
}

struct EngineAnalysis {
    let evaluation: Int
    let bestMove: String
    let principalVariation: [String]
    let secondBestEvaluation: Int?
    let secondBestMove: String?
}

enum ChessCoachError: LocalizedError {
    case invalidUsername
    case playerNotFound
    case noGames
    case malformedGame
    case missingEngineNetwork
    case engineStopped
    case engineFailure(String)

    var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "Der Chess.com-Username sieht ungültig aus."
        case .playerNotFound:
            return "Der Chess.com-Spieler wurde nicht gefunden."
        case .noGames:
            return "Für diesen Account wurden keine normalen Schachpartien gefunden."
        case .malformedGame:
            return "Eine Partie konnte nicht gelesen werden."
        case .missingEngineNetwork:
            return "Die Stockfish-Netzwerkdatei fehlt in der App."
        case .engineStopped:
            return "Die Schach-Engine wurde unerwartet beendet."
        case .engineFailure(let message):
            return message
        }
    }
}

// MARK: - Chess.com DTOs

struct ChessComArchiveList: Decodable {
    let archives: [String]
}

struct ChessComArchive: Decodable {
    let games: [ChessComGameDTO]
}

struct ChessComGameDTO: Decodable {
    let url: String
    let pgn: String?
    let timeControl: String?
    let endTime: Int
    let rated: Bool?
    let rules: String?
    let timeClass: String?
    let uuid: String?
    let white: ChessComPlayerDTO
    let black: ChessComPlayerDTO

    enum CodingKeys: String, CodingKey {
        case url, pgn, rated, rules, uuid, white, black
        case timeControl = "time_control"
        case endTime = "end_time"
        case timeClass = "time_class"
    }
}

struct ChessComPlayerDTO: Decodable {
    let rating: Int
    let result: String
    let username: String
}

struct ChessComProfileDTO: Decodable {
    let username: String
    let name: String?
    let avatar: String?
}

struct ChessComStatsDTO: Decodable {
    let chessRapid: ChessComRatingBlock?
    let chessBlitz: ChessComRatingBlock?
    let chessBullet: ChessComRatingBlock?

    enum CodingKeys: String, CodingKey {
        case chessRapid = "chess_rapid"
        case chessBlitz = "chess_blitz"
        case chessBullet = "chess_bullet"
    }

    var preferredRating: (Int, String)? {
        if let value = chessRapid?.last?.rating { return (value, "Rapid") }
        if let value = chessBlitz?.last?.rating { return (value, "Blitz") }
        if let value = chessBullet?.last?.rating { return (value, "Bullet") }
        return nil
    }
}

struct ChessComRatingBlock: Decodable {
    let last: ChessComRatingLast?
}

struct ChessComRatingLast: Decodable {
    let rating: Int
}
