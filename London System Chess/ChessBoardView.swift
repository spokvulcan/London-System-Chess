//
//  ChessBoardView.swift
//  London System Chess
//
//  Renders an actual chess position from a FEN string. Used by the board card so
//  the player sees the real position behind any node. Pieces are Unicode glyphs
//  tinted by color; the board is White-at-bottom.
//

import SwiftUI

struct ChessBoardView: View {
    /// Full or placement-only FEN. Only the piece-placement field is read.
    let fen: String

    private let light = Color(red: 0.93, green: 0.90, blue: 0.82)
    private let dark = Color(red: 0.46, green: 0.58, blue: 0.40)

    var body: some View {
        let ranks = Self.placement(from: fen)
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let square = side / 8
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { col in
                            ZStack {
                                Rectangle()
                                    .fill((row + col).isMultiple(of: 2) ? light : dark)
                                if let piece = ranks[safe: row]?[safe: col] ?? nil {
                                    Text(Self.glyph(for: piece))
                                        .font(.system(size: square * 0.78))
                                        .foregroundStyle(piece.isUppercase ? .white : .black)
                                        .shadow(color: .black.opacity(0.25), radius: 0.5)
                                }
                            }
                            .frame(width: square, height: square)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: square * 0.12))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Expands the FEN placement field into 8 ranks (row 0 = rank 8) of optional
    /// piece characters.
    static func placement(from fen: String) -> [[Character?]] {
        let placement = fen.split(separator: " ").first.map(String.init) ?? fen
        return placement.split(separator: "/").map { rank in
            var squares: [Character?] = []
            for ch in rank {
                if let empty = ch.wholeNumberValue {
                    squares.append(contentsOf: Array(repeating: nil, count: empty))
                } else {
                    squares.append(ch)
                }
            }
            // Pad/truncate defensively to 8.
            if squares.count < 8 { squares.append(contentsOf: Array(repeating: nil, count: 8 - squares.count)) }
            return Array(squares.prefix(8))
        }
    }

    /// Maps a FEN piece letter to its filled Unicode chess glyph (color via tint).
    static func glyph(for piece: Character) -> String {
        switch piece.lowercased() {
        case "k": "\u{265A}"
        case "q": "\u{265B}"
        case "r": "\u{265C}"
        case "b": "\u{265D}"
        case "n": "\u{265E}"
        case "p": "\u{265F}"
        default: ""
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ChessBoardView(fen: "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq - 0 1")
        .padding()
}
