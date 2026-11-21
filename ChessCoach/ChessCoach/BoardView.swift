import SwiftUI

struct ChessBoardViewLite: View {
    let fen: String
    var whiteAtBottom: Bool = true
    var highlightedMove: String? = nil
    var suggestedMove: String? = nil
    var selectedSquare: String? = nil
    var onSquareTap: ((String) -> Void)? = nil

    private var pieces: [String: Character] { BoardFENParser.pieces(from: fen) }
    private var moveSquares: Set<String> { squares(from: highlightedMove) }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let cell = side / 8

            ZStack {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 0), count: 8), spacing: 0) {
                    ForEach(0..<64, id: \.self) { index in
                        let square = squareName(at: index)
                        let piece = pieces[square]
                        let displayRow = index / 8
                        let displayCol = index % 8
                        BoardSquareCell(
                            square: square,
                            piece: piece,
                            size: cell,
                            isLight: isLightSquare(square),
                            isHighlighted: moveSquares.contains(square),
                            isSelected: selectedSquare == square,
                            assetName: piece.map(pieceAssetName),
                            showRank: displayCol == 0,
                            showFile: displayRow == 7
                        ) {
                            guard onSquareTap != nil else { return }
                            Haptics.move()
                            onSquareTap?(square)
                        }
                    }
                }
                .frame(width: side, height: side)

                if let suggestedMove, suggestedMove.count >= 4 {
                    BoardArrowOverlay(move: suggestedMove, whiteAtBottom: whiteAtBottom)
                        .frame(width: side, height: side)
                        .allowsHitTesting(false)
                        .id(suggestedMove + fen)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.black.opacity(0.28), lineWidth: 1)
            )
            .animation(.spring(response: 0.38, dampingFraction: 0.84), value: fen)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func squareName(at index: Int) -> String {
        let displayRow = index / 8
        let displayCol = index % 8
        let fileIndex = whiteAtBottom ? displayCol : 7 - displayCol
        let rank = whiteAtBottom ? 8 - displayRow : displayRow + 1
        let files = Array("abcdefgh")
        return "\(files[fileIndex])\(rank)"
    }

    private func isLightSquare(_ square: String) -> Bool {
        let chars = Array(square)
        guard chars.count == 2,
              let fileASCII = chars[0].asciiValue,
              let rank = chars[1].wholeNumberValue else { return false }
        let file = Int(fileASCII) - 97
        return (file + rank) % 2 == 1
    }

    private func squares(from move: String?) -> Set<String> {
        guard let move, move.count >= 4 else { return [] }
        let chars = Array(move)
        return [String(chars[0...1]), String(chars[2...3])]
    }

    private func pieceAssetName(for piece: Character) -> String {
        switch piece {
        case "K": return "wK"
        case "Q": return "wQ"
        case "R": return "wR"
        case "B": return "wB"
        case "N": return "wN"
        case "P": return "wP"
        case "k": return "bK"
        case "q": return "bQ"
        case "r": return "bR"
        case "b": return "bB"
        case "n": return "bN"
        case "p": return "bP"
        default: return "wP"
        }
    }
}

private struct BoardSquareCell: View {
    let square: String
    let piece: Character?
    let size: CGFloat
    let isLight: Bool
    let isHighlighted: Bool
    let isSelected: Bool
    let assetName: String?
    let showRank: Bool
    let showFile: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(backgroundColor)

            if let assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.026)
                    .shadow(color: .black.opacity(0.18), radius: 1.1, y: 0.8)
            }

            if showRank || showFile {
                VStack {
                    if showRank {
                        HStack {
                            Text(String(square.last ?? " "))
                                .font(.system(size: max(7, size * 0.15), weight: .bold))
                                .foregroundStyle(labelColor.opacity(0.68))
                            Spacer()
                        }
                    }
                    Spacer()
                    if showFile {
                        HStack {
                            Spacer()
                            Text(String(square.first ?? " "))
                                .font(.system(size: max(7, size * 0.15), weight: .bold))
                                .foregroundStyle(labelColor.opacity(0.68))
                        }
                    }
                }
                .padding(size * 0.055)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.reviewGold.opacity(isLight ? 0.78 : 0.62)
        }
        if isHighlighted {
            return Color(red: 0.56, green: 0.64, blue: 0.42)
        }
        return isLight
            ? Color(red: 0.84, green: 0.85, blue: 0.89)
            : Color(red: 0.27, green: 0.31, blue: 0.39)
    }

    private var labelColor: Color {
        isLight ? Color(red: 0.27, green: 0.31, blue: 0.39) : Color(red: 0.84, green: 0.85, blue: 0.89)
    }
}

private enum BoardFENParser {
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
                if let emptyCount = char.wholeNumberValue {
                    fileIndex += emptyCount
                } else if fileIndex < 8 {
                    output["\(files[fileIndex])\(rank)"] = char
                    fileIndex += 1
                }
            }
        }
        return output
    }
}

private struct BoardArrowOverlay: View {
    let move: String
    let whiteAtBottom: Bool
    @State private var revealed = false

    var body: some View {
        GeometryReader { geo in
            let chars = Array(move)
            let from = chars.count >= 4 ? String(chars[0...1]) : ""
            let to = chars.count >= 4 ? String(chars[2...3]) : ""
            let start = point(for: from, size: geo.size)
            let end = point(for: to, size: geo.size)
            let cell = geo.size.width / 8

            ZStack {
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .trim(from: 0, to: revealed ? 1 : 0)
                .stroke(
                    Color.coachCyan.opacity(0.92),
                    style: StrokeStyle(lineWidth: max(5, cell * 0.11), lineCap: .round)
                )
                .shadow(color: .black.opacity(0.35), radius: 3)

                Circle()
                    .fill(Color.coachCyan)
                    .frame(width: cell * 0.22, height: cell * 0.22)
                    .position(end)
                    .scaleEffect(revealed ? 1 : 0.1)
                    .opacity(revealed ? 1 : 0)
            }
            .onAppear {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.76)) {
                    revealed = true
                }
            }
        }
    }

    private func point(for square: String, size: CGSize) -> CGPoint {
        let chars = Array(square)
        guard chars.count == 2,
              let fileASCII = chars[0].asciiValue,
              let rank = chars[1].wholeNumberValue else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        let file = Int(fileASCII) - 97
        let col = whiteAtBottom ? file : 7 - file
        let row = whiteAtBottom ? 8 - rank : rank - 1
        let cell = size.width / 8
        return CGPoint(x: (CGFloat(col) + 0.5) * cell, y: (CGFloat(row) + 0.5) * cell)
    }
}

struct EvaluationStrip: View {
    let centipawns: Int

    private var whiteFraction: Double {
        if centipawns > 90_000 { return 0.97 }
        if centipawns < -90_000 { return 0.03 }
        let logistic = 1.0 / (1.0 + exp(-Double(centipawns) / 420.0))
        return min(0.97, max(0.03, logistic))
    }

    var body: some View {
        GeometryReader { geo in
            let whiteHeight = geo.size.height * whiteFraction

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.72))

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .frame(height: whiteHeight)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: whiteFraction)
        }
    }
}

struct BoardWithEvaluation: View {
    let fen: String
    let whiteAtBottom: Bool
    let evaluation: Int?
    let highlightedMove: String?
    let suggestedMove: String?

    var body: some View {
        HStack(spacing: 7) {
            if let evaluation {
                EvaluationStrip(centipawns: evaluation)
                    .frame(width: 14)
            }

            ChessBoardViewLite(
                fen: fen,
                whiteAtBottom: whiteAtBottom,
                highlightedMove: highlightedMove,
                suggestedMove: suggestedMove
            )
        }
    }
}
