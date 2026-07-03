//
//  ChessBoardView.swift
//  London System Chess
//
//  Renders an actual chess position from a FEN string — the app's core learning
//  surface. Pieces are the Chessnut set (vector PDFs, see docs/adr/0005); moves
//  slide (identity via BoardTransition); coordinates sit inside the edge squares
//  chess.com-style and auto-hide when squares get too small; colors follow
//  light/dark mode from one BoardTheme. Interaction is opt-in via `onSquareTap` —
//  render-only callers are untouched.
//

import SwiftUI

/// Which side sits at the bottom of the displayed board.
enum BoardOrientation {
    case white, black
}

/// Whether the a–h / 1–8 labels are drawn. `.automatic` shows them whenever
/// squares are big enough to keep them readable.
enum BoardCoordinateVisibility {
    case automatic, visible, hidden
}

/// The board's palette for one color scheme. Day keeps the original cream /
/// London green; night is the same green identity, dimmed (see the piece-set
/// comparison in docs/adr/0005).
struct BoardTheme {
    let lightSquare: Color
    let darkSquare: Color
    /// Filled overlay for the square the player has picked a piece up from —
    /// deliberately hotter than the pale-yellow last-move highlight.
    let selection: Color

    static let day = BoardTheme(
        lightSquare: Color(red: 0.93, green: 0.90, blue: 0.82),
        darkSquare: Color(red: 0.46, green: 0.58, blue: 0.40),
        selection: Color(red: 1.0, green: 0.72, blue: 0.10)
    )

    static let night = BoardTheme(
        lightSquare: Color(red: 0.44, green: 0.48, blue: 0.35),
        darkSquare: Color(red: 0.28, green: 0.33, blue: 0.24),
        selection: Color(red: 1.0, green: 0.72, blue: 0.10)
    )

    static func resolved(for scheme: ColorScheme) -> BoardTheme {
        scheme == .dark ? .night : .day
    }
}

struct ChessBoardView: View {
    /// Full or placement-only FEN. Only the piece-placement field is read.
    let fen: String
    /// Which side is at the bottom. Square names stay canonical algebraic.
    var orientation: BoardOrientation = .white
    /// The square the player has picked up a piece from, e.g. "e2".
    var selectedSquare: String? = nil
    /// Square → tint overlays (last move, reveal, wrong-answer flash).
    var highlights: [String: Color] = [:]
    /// Coordinate labels; `.automatic` hides them below thumbnail size.
    var coordinates: BoardCoordinateVisibility = .automatic
    /// Present = the board takes input; called with the tapped square name.
    var onSquareTap: ((String) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var pieces: [BoardPiece] = []

    /// `pieces` lags `fen` by one lifecycle tick (state updates in `onChange`);
    /// deriving the initial set here keeps static renders (previews,
    /// ImageRenderer) from drawing an empty board.
    private var displayedPieces: [BoardPiece] {
        pieces.isEmpty ? BoardTransition.pieces(from: Self.placement(from: fen)) : pieces
    }

    /// Squares narrower than this get no coordinate labels in `.automatic`.
    private static let coordinateThreshold: CGFloat = 26

    var body: some View {
        let theme = BoardTheme.resolved(for: colorScheme)
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let square = side / 8
            ZStack(alignment: .topLeading) {
                squaresLayer(theme: theme, square: square)
                if showsCoordinates(square: square) {
                    coordinatesLayer(theme: theme, square: square)
                }
                piecesLayer(square: square)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: square * 0.12))
            .contentShape(RoundedRectangle(cornerRadius: square * 0.12))
            .gesture(tapGesture(square: square), including: onSquareTap == nil ? .none : .all)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: fen, initial: true) { _, newFEN in
            let placement = Self.placement(from: newFEN)
            if pieces.isEmpty {
                pieces = BoardTransition.pieces(from: placement)
            } else {
                withAnimation(.snappy(duration: 0.3)) {
                    pieces = BoardTransition.pieces(pieces, movedTo: placement)
                }
            }
        }
    }

    // MARK: - Layers

    private func squaresLayer(theme: BoardTheme, square: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { col in
                        let name = squareName(displayRow: row, displayCol: col)
                        ZStack {
                            Rectangle()
                                .fill((row + col).isMultiple(of: 2) ? theme.lightSquare : theme.darkSquare)
                            if let tint = highlights[name] {
                                Rectangle().fill(tint.opacity(0.5))
                            }
                            if name == selectedSquare {
                                Rectangle().fill(theme.selection.opacity(0.6))
                            }
                        }
                        .frame(width: square, height: square)
                    }
                }
            }
        }
    }

    /// Rank digits in the top-left of the leftmost column, file letters in the
    /// bottom-right of the bottom row — inside the squares, tinted with the
    /// opposite square color so they read on either background.
    private func coordinatesLayer(theme: BoardTheme, square: CGFloat) -> some View {
        let font = Font.system(size: square * 0.24, weight: .semibold, design: .rounded)
        let inset = square * 0.06
        return ZStack(alignment: .topLeading) {
            ForEach(0..<8, id: \.self) { row in
                Text(String(rank(displayRow: row)))
                    .font(font)
                    .foregroundStyle(row.isMultiple(of: 2) ? theme.darkSquare : theme.lightSquare)
                    .padding(.leading, inset)
                    .offset(x: 0, y: CGFloat(row) * square + inset * 0.5)
            }
            ForEach(0..<8, id: \.self) { col in
                Text(String(file(displayCol: col)))
                    .font(font)
                    .foregroundStyle((col + 7).isMultiple(of: 2) ? theme.darkSquare : theme.lightSquare)
                    .padding(.trailing, inset)
                    .frame(width: square, alignment: .trailing)
                    .offset(x: CGFloat(col) * square, y: 8 * square - square * 0.24 - inset * 1.6)
            }
        }
    }

    private func piecesLayer(square: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(displayedPieces) { piece in
                Image("Chessnut/\(Self.assetName(for: piece.kind))")
                    .resizable()
                    .scaledToFit()
                    .frame(width: square, height: square)
                    .shadow(color: .black.opacity(0.15), radius: square * 0.02, y: square * 0.03)
                    .position(center(of: piece.square, square: square))
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .frame(width: square * 8, height: square * 8)
    }

    private func tapGesture(square: CGFloat) -> some Gesture {
        SpatialTapGesture().onEnded { value in
            let col = min(7, max(0, Int(value.location.x / square)))
            let row = min(7, max(0, Int(value.location.y / square)))
            onSquareTap?(squareName(displayRow: row, displayCol: col))
        }
    }

    private func showsCoordinates(square: CGFloat) -> Bool {
        switch coordinates {
        case .visible: true
        case .hidden: false
        case .automatic: square >= Self.coordinateThreshold
        }
    }

    // MARK: - Orientation mapping

    private func rank(displayRow row: Int) -> Int {
        Self.rank(displayRow: row, orientation: orientation)
    }

    private func file(displayCol col: Int) -> Character {
        Self.file(displayCol: col, orientation: orientation)
    }

    private func squareName(displayRow row: Int, displayCol col: Int) -> String {
        Self.squareName(displayRow: row, displayCol: col, orientation: orientation)
    }

    private func center(of square: String, square size: CGFloat) -> CGPoint {
        let cell = Self.displayCell(of: square, orientation: orientation)
        return CGPoint(x: (CGFloat(cell.col) + 0.5) * size, y: (CGFloat(cell.row) + 0.5) * size)
    }

    static func rank(displayRow row: Int, orientation: BoardOrientation) -> Int {
        orientation == .white ? 8 - row : row + 1
    }

    static func file(displayCol col: Int, orientation: BoardOrientation) -> Character {
        Character(UnicodeScalar(97 + (orientation == .white ? col : 7 - col))!)
    }

    /// Algebraic name of the square drawn at a display cell (row 0 = top).
    static func squareName(displayRow row: Int, displayCol col: Int, orientation: BoardOrientation) -> String {
        "\(file(displayCol: col, orientation: orientation))\(rank(displayRow: row, orientation: orientation))"
    }

    /// Inverse of `squareName`: where an algebraic square is drawn.
    static func displayCell(of square: String, orientation: BoardOrientation) -> (row: Int, col: Int) {
        guard let fileValue = square.first?.asciiValue,
              let rankValue = square.last?.wholeNumberValue
        else { return (0, 0) }
        let file = Int(fileValue) - 97
        switch orientation {
        case .white: return (8 - rankValue, file)
        case .black: return (rankValue - 1, 7 - file)
        }
    }

    // MARK: - FEN helpers

    /// The piece character on a square, from a FEN placement (uppercase = White).
    static func piece(at square: String, in fen: String) -> Character? {
        guard square.count == 2,
              let file = square.first?.asciiValue, (97...104).contains(file),
              let rank = square.last?.wholeNumberValue, (1...8).contains(rank)
        else { return nil }
        let ranks = placement(from: fen)
        return ranks[safe: 8 - rank]?[safe: Int(file) - 97] ?? nil
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

    /// Asset-catalog name for a FEN piece letter, e.g. 'N' → "wN", 'q' → "bQ".
    static func assetName(for kind: Character) -> String {
        (kind.isUppercase ? "w" : "b") + kind.uppercased()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Day, coordinates") {
    ChessBoardView(
        fen: "rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 2",
        selectedSquare: "c1",
        highlights: ["d5": .yellow, "d4": .yellow]
    )
    .padding()
}

#Preview("Night") {
    ChessBoardView(fen: "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq - 0 1")
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Black at bottom") {
    ChessBoardView(
        fen: "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq - 0 1",
        orientation: .black
    )
    .padding()
}

#Preview("Thumbnail — no coordinates") {
    ChessBoardView(fen: "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq - 0 1")
        .frame(width: 120)
        .padding()
}
