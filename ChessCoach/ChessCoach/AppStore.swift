import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var username: String = ""
    @Published var profile: PlayerSnapshot?
    @Published var games: [ImportedGame] = []
    @Published var isSyncing = false
    @Published var syncMessage = ""
    @Published var errorMessage: String?
    @Published var reviewingGameID: String?
    @Published var reviewProgress: Double = 0
    @Published var reviewStatus = ""

    private let service = ChessComService()
    private let defaults = UserDefaults.standard

    init() {
        username = defaults.string(forKey: "chesscoach.username") ?? ""
        loadCache()
    }

    var reviewedGamesCount: Int {
        games.filter { $0.review != nil }.count
    }

    var averageAccuracy: Double? {
        let values = games.compactMap { $0.review?.accuracy }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var puzzles: [TrainingPuzzle] {
        var output: [TrainingPuzzle] = []

        for game in games {
            guard let review = game.review else { continue }
            for move in review.moves {
                let whiteMove = move.ply % 2 == 1
                let myMove = (game.myColor == "white" && whiteMove) || (game.myColor == "black" && !whiteMove)
                guard myMove, move.grade.isTrainingCandidate, !move.bestMove.isEmpty else { continue }

                output.append(
                    TrainingPuzzle(
                        id: "\(game.id)-\(move.ply)",
                        gameID: game.id,
                        opponent: game.opponent,
                        ply: move.ply,
                        fen: move.fenBefore,
                        bestMove: move.bestMove,
                        playedMove: move.move,
                        grade: move.grade,
                        explanation: move.explanation,
                        whiteToMove: move.ply % 2 == 1
                    )
                )
            }
        }

        return output
    }

    func connect(username newUsername: String) async -> Bool {
        isSyncing = true
        errorMessage = nil
        syncMessage = "Chess.com-Profil wird verbunden"

        defer {
            isSyncing = false
            syncMessage = ""
        }

        do {
            let (snapshot, fetchedGames) = try await service.loadPlayer(username: newUsername)
            let existingReviews = Dictionary(uniqueKeysWithValues: games.compactMap { game -> (String, GameReview)? in
                guard let review = game.review, review.isModernReview else { return nil }
                return (game.id, review)
            })

            profile = snapshot
            username = snapshot.username
            defaults.set(snapshot.username, forKey: "chesscoach.username")

            games = fetchedGames.map { game in
                var copy = game
                copy.review = existingReviews[game.id]
                return copy
            }
            saveCache()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func sync() async {
        guard !username.isEmpty, !isSyncing else { return }
        _ = await connect(username: username)
    }

    func review(gameID: String) async {
        guard reviewingGameID == nil, let game = games.first(where: { $0.id == gameID }) else { return }

        reviewingGameID = gameID
        reviewProgress = 0
        reviewStatus = "Stockfish wird gestartet"
        errorMessage = nil

        defer {
            reviewingGameID = nil
            reviewStatus = ""
        }

        do {
            let reviewer = StockfishReviewer()
            let result = try await reviewer.review(game: game) { [weak self] progress, status in
                await MainActor.run {
                    self?.reviewProgress = progress
                    self?.reviewStatus = status
                }
            }

            if let index = games.firstIndex(where: { $0.id == gameID }) {
                games[index].review = result
            }
            saveCache()
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearData() {
        username = ""
        profile = nil
        games = []
        errorMessage = nil
        defaults.removeObject(forKey: "chesscoach.username")
        try? FileManager.default.removeItem(at: cacheURL)
    }

    private var cacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("ChessCoach", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("cache.json")
    }

    private func saveCache() {
        let payload = CachePayload(profile: profile, games: games)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let payload = try? JSONDecoder().decode(CachePayload.self, from: data) else {
            return
        }
        profile = payload.profile
        games = payload.games.map { game in
            var copy = game
            if let review = copy.review, !review.isModernReview {
                copy.review = nil
            }
            return copy
        }
    }
}

private struct CachePayload: Codable {
    let profile: PlayerSnapshot?
    let games: [ImportedGame]
}
