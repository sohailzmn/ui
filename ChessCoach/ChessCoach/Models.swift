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

    var blunderCount: Int { moves.filter { $0.grade == .blunder }.count }
    var mistakeCount: Int { moves.filter { $0.grade == .mistake }.count }
    var inaccuracyCount: Int { moves.filter { $0.grade == .inaccuracy }.count }
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

    var moveNumberText: String {
        let number = (ply + 1) / 2
        return ply % 2 == 1 ? "\(number)." : "\(number)..."
    }
}

enum ReviewGrade: String, Codable, CaseIterable {
    case best = "Best"
    case great = "Great"
    case inaccuracy = "Inaccuracy"
    case mistake = "Mistake"
    case blunder = "Blunder"

    var symbol: String {
        switch self {
        case .best: return "sparkles"
        case .great: return "hand.thumbsup.fill"
        case .inaccuracy: return "exclamationmark.circle.fill"
        case .mistake: return "exclamationmark.triangle.fill"
        case .blunder: return "bolt.trianglebadge.exclamationmark.fill"
        }
    }

    var shortLabel: String {
        switch self {
        case .best: return "Best"
        case .great: return "Good"
        case .inaccuracy: return "?!"
        case .mistake: return "?"
        case .blunder: return "??"
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
