import Foundation

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

    static func friendlyMove(_ move: String, in fen: String) -> String {
        let chars = Array(move)
        guard chars.count >= 4 else { return move }

        let from = String(chars[0...1])
        let to = String(chars[2...3])
        let board = pieces(from: fen)
        guard let piece = board[from] else { return move }

        let upper = Character(String(piece).uppercased())
        if upper == "K" {
            if (from == "e1" && to == "g1") || (from == "e8" && to == "g8") {
                return "kurze Rochade"
            }
            if (from == "e1" && to == "c1") || (from == "e8" && to == "c8") {
                return "lange Rochade"
            }
        }

        let capture = board[to] != nil
        let connector = capture ? "×" : "–"
        return "\(pieceName(piece)) \(from)\(connector)\(to)"
    }

    static func phaseName(for move: MoveReview, totalPlies: Int) -> String {
        if move.ply <= 20 { return "Eröffnung" }
        if move.ply >= max(22, totalPlies - max(12, totalPlies / 4)) { return "Endspiel" }
        return "Mittelspiel"
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
}
