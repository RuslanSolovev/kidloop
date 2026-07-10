// features/games/chess/chess_widgets.dart
import 'package:flutter/material.dart';
import 'chess_models.dart';

class ChessBoardWidget extends StatelessWidget {
  final List<List<ChessPiece?>> board;
  final Position? selectedPosition;
  final List<Position> legalMoves;
  final Position? lastMoveFrom;
  final Position? lastMoveTo;
  final bool isFlipped;
  final bool isWhiteTurn;
  final bool isCheck;
  final Function(Position) onSquareTap;

  const ChessBoardWidget({
    super.key,
    required this.board,
    this.selectedPosition,
    required this.legalMoves,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.isFlipped = false,
    required this.isWhiteTurn,
    this.isCheck = false,
    required this.onSquareTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width - 32;
    final squareSize = size / 8;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            childAspectRatio: 1,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final row = isFlipped ? index ~/ 8 : 7 - (index ~/ 8);
            final col = isFlipped ? 7 - (index % 8) : index % 8;
            final pos = Position(row, col);
            final piece = board[row][col];
            final isSelected = selectedPosition == pos;
            final isLegal = legalMoves.contains(pos);
            final isLastMove = pos == lastMoveFrom || pos == lastMoveTo;
            final isLight = (row + col) % 2 == 0;

            return GestureDetector(
              onTap: () => onSquareTap(pos),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.yellow.withOpacity(0.6)
                      : isLastMove
                      ? Colors.green.withOpacity(0.3)
                      : isLight
                      ? const Color(0xFFF0D9B5)
                      : const Color(0xFFB58863),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (piece != null) _buildPiece(piece, squareSize),
                    if (isLegal && piece != null)
                      Container(
                        width: squareSize * 0.85,
                        height: squareSize * 0.85,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.red.withOpacity(0.5), width: 3),
                        ),
                      ),
                    if (isLegal && piece == null)
                      Container(
                        width: squareSize * 0.25,
                        height: squareSize * 0.25,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPiece(ChessPiece piece, double squareSize) {
    final pieceChar = _getPieceChar(piece);
    return Text(
      pieceChar,
      style: TextStyle(fontSize: squareSize * 0.65, height: 1),
    );
  }

  String _getPieceChar(ChessPiece piece) {
    const whitePieces = {
      PieceType.king: '♔',
      PieceType.queen: '♕',
      PieceType.rook: '♖',
      PieceType.bishop: '♗',
      PieceType.knight: '♘',
      PieceType.pawn: '♙',
    };
    const blackPieces = {
      PieceType.king: '♚',
      PieceType.queen: '♛',
      PieceType.rook: '♜',
      PieceType.bishop: '♝',
      PieceType.knight: '♞',
      PieceType.pawn: '♟',
    };
    return piece.color == PieceColor.white
        ? whitePieces[piece.type] ?? '?'
        : blackPieces[piece.type] ?? '?';
  }
}

class ChessTimerWidget extends StatelessWidget {
  final int millisecondsLeft;
  final bool isActive;
  final String playerName;
  final bool isTop;

  const ChessTimerWidget({
    super.key,
    required this.millisecondsLeft,
    required this.isActive,
    required this.playerName,
    this.isTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalSeconds = (millisecondsLeft / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isLow = totalSeconds < 30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? (isLow
            ? Colors.red.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1))
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? (isLow
              ? Colors.red.withOpacity(0.5)
              : Colors.orange.withOpacity(0.3))
              : Colors.grey.withOpacity(0.2),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              playerName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color:
              isActive ? (isLow ? Colors.red : Colors.orange) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class CapturedPiecesWidget extends StatelessWidget {
  final List<ChessPiece?> pieces;
  final bool isMine;

  const CapturedPiecesWidget({
    super.key,
    required this.pieces,
    this.isMine = true,
  });

  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) return const SizedBox.shrink();

    // Показываем только фигуры определённого цвета
    final targetColor = isMine ? PieceColor.black : PieceColor.white;
    final filtered = pieces.where((p) => p?.color == targetColor).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 2,
        children: filtered
            .map((p) => Text(_getChar(p), style: const TextStyle(fontSize: 16)))
            .toList(),
      ),
    );
  }

  String _getChar(ChessPiece? piece) {
    if (piece == null) return '';
    const chars = {
      PieceType.queen: {PieceColor.white: '♛', PieceColor.black: '♕'},
      PieceType.rook: {PieceColor.white: '♜', PieceColor.black: '♖'},
      PieceType.bishop: {PieceColor.white: '♝', PieceColor.black: '♗'},
      PieceType.knight: {PieceColor.white: '♞', PieceColor.black: '♘'},
      PieceType.pawn: {PieceColor.white: '♟', PieceColor.black: '♙'},
    };
    return chars[piece.type]?[piece.color] ?? '';
  }
}