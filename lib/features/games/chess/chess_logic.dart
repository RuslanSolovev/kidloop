// features/games/chess/chess_logic.dart
import 'chess_models.dart';

class ChessLogic {
  List<List<ChessPiece?>> _board = List.generate(8, (_) => List.filled(8, null));
  List<ChessMove> _moves = [];
  bool _isWhiteTurn = true;
  Position? _enPassantTarget;
  bool _whiteCanCastleKingside = true;
  bool _whiteCanCastleQueenside = true;
  bool _blackCanCastleKingside = true;
  bool _blackCanCastleQueenside = true;
  int _halfMoveClock = 0;
  int _fullMoveNumber = 1;

  bool get isWhiteTurn => _isWhiteTurn;
  List<ChessMove> get moves => List.unmodifiable(_moves);
  String get currentFen => _toFen();
  bool get isCheck =>
      _isInCheck(_isWhiteTurn ? PieceColor.white : PieceColor.black);
  bool get isCheckmate => isCheck && _getAllLegalMoves().isEmpty;
  bool get isStalemate => !isCheck && _getAllLegalMoves().isEmpty;
  List<ChessPiece?> get capturedPieces => _getCapturedPieces();

  // 🔥 Геттер для получения текущего состояния доски
  List<List<ChessPiece?>> get board => _board;

  ChessLogic() {
    _setupInitialPosition();
  }

  void _setupInitialPosition() {
    _board = List.generate(8, (_) => List.filled(8, null));

    for (int col = 0; col < 8; col++) {
      _board[6][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.white);
      _board[1][col] = ChessPiece(type: PieceType.pawn, color: PieceColor.black);
    }

    _board[7][0] = ChessPiece(type: PieceType.rook, color: PieceColor.white);
    _board[7][7] = ChessPiece(type: PieceType.rook, color: PieceColor.white);
    _board[0][0] = ChessPiece(type: PieceType.rook, color: PieceColor.black);
    _board[0][7] = ChessPiece(type: PieceType.rook, color: PieceColor.black);

    _board[7][1] = ChessPiece(type: PieceType.knight, color: PieceColor.white);
    _board[7][6] = ChessPiece(type: PieceType.knight, color: PieceColor.white);
    _board[0][1] = ChessPiece(type: PieceType.knight, color: PieceColor.black);
    _board[0][6] = ChessPiece(type: PieceType.knight, color: PieceColor.black);

    _board[7][2] = ChessPiece(type: PieceType.bishop, color: PieceColor.white);
    _board[7][5] = ChessPiece(type: PieceType.bishop, color: PieceColor.white);
    _board[0][2] = ChessPiece(type: PieceType.bishop, color: PieceColor.black);
    _board[0][5] = ChessPiece(type: PieceType.bishop, color: PieceColor.black);

    _board[7][3] = ChessPiece(type: PieceType.queen, color: PieceColor.white);
    _board[0][3] = ChessPiece(type: PieceType.queen, color: PieceColor.black);

    _board[7][4] = ChessPiece(type: PieceType.king, color: PieceColor.white);
    _board[0][4] = ChessPiece(type: PieceType.king, color: PieceColor.black);

    _isWhiteTurn = true;
    _moves = [];
    _enPassantTarget = null;
    _whiteCanCastleKingside = true;
    _whiteCanCastleQueenside = true;
    _blackCanCastleKingside = true;
    _blackCanCastleQueenside = true;
    _halfMoveClock = 0;
    _fullMoveNumber = 1;
  }

  void loadFromFen(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 6) return;

    final rows = parts[0].split('/');
    _board = List.generate(8, (_) => List.filled(8, null));

    for (int row = 0; row < 8; row++) {
      int col = 0;
      for (int i = 0; i < rows[row].length; i++) {
        final char = rows[row][i];
        if (int.tryParse(char) != null) {
          col += int.parse(char);
        } else {
          final color = char == char.toUpperCase()
              ? PieceColor.white
              : PieceColor.black;
          final type = _charToPieceType(char.toLowerCase());
          if (type != null) {
            _board[row][col] = ChessPiece(type: type, color: color);
          }
          col++;
        }
      }
    }

    _isWhiteTurn = parts[1] == 'w';

    final castling = parts[2];
    _whiteCanCastleKingside = castling.contains('K');
    _whiteCanCastleQueenside = castling.contains('Q');
    _blackCanCastleKingside = castling.contains('k');
    _blackCanCastleQueenside = castling.contains('q');

    _enPassantTarget =
    parts[3] != '-' ? Position.fromNotation(parts[3]) : null;

    _halfMoveClock = int.tryParse(parts[4]) ?? 0;
    _fullMoveNumber = int.tryParse(parts[5]) ?? 1;
  }

  PieceType? _charToPieceType(String char) {
    switch (char) {
      case 'k': return PieceType.king;
      case 'q': return PieceType.queen;
      case 'r': return PieceType.rook;
      case 'b': return PieceType.bishop;
      case 'n': return PieceType.knight;
      case 'p': return PieceType.pawn;
      default: return null;
    }
  }

  String _toFen() {
    final sb = StringBuffer();

    for (int row = 0; row < 8; row++) {
      int emptyCount = 0;
      for (int col = 0; col < 8; col++) {
        final piece = _board[row][col];
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            sb.write(emptyCount);
            emptyCount = 0;
          }
          sb.write(piece.fenSymbol);
        }
      }
      if (emptyCount > 0) sb.write(emptyCount);
      if (row < 7) sb.write('/');
    }

    sb.write(' ${_isWhiteTurn ? 'w' : 'b'} ');

    String castling = '';
    if (_whiteCanCastleKingside) castling += 'K';
    if (_whiteCanCastleQueenside) castling += 'Q';
    if (_blackCanCastleKingside) castling += 'k';
    if (_blackCanCastleQueenside) castling += 'q';
    sb.write(castling.isEmpty ? '-' : castling);

    sb.write(' ${_enPassantTarget?.notation ?? '-'}');
    sb.write(' $_halfMoveClock $_fullMoveNumber');

    return sb.toString();
  }

  List<Position> getLegalMoves(Position pos) {
    final piece = _board[pos.row][pos.col];
    if (piece == null) return [];
    if ((piece.color == PieceColor.white) != _isWhiteTurn) return [];

    List<Position> moves = [];

    switch (piece.type) {
      case PieceType.pawn:
        moves = _getPawnMoves(pos, piece.color);
        break;
      case PieceType.knight:
        moves = _getKnightMoves(pos, piece.color);
        break;
      case PieceType.bishop:
        moves = _getBishopMoves(pos, piece.color);
        break;
      case PieceType.rook:
        moves = _getRookMoves(pos, piece.color);
        break;
      case PieceType.queen:
        moves = [..._getBishopMoves(pos, piece.color), ..._getRookMoves(pos, piece.color)];
        break;
      case PieceType.king:
        moves = _getKingMoves(pos, piece.color);
        break;
    }

    return moves.where((to) {
      final captured = _board[to.row][to.col];
      _board[to.row][to.col] = piece;
      _board[pos.row][pos.col] = null;
      final inCheck = _isInCheck(piece.color);
      _board[pos.row][pos.col] = piece;
      _board[to.row][to.col] = captured;
      return !inCheck;
    }).toList();
  }

  List<Position> _getAllLegalMoves() {
    final moves = <Position>[];
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = _board[row][col];
        if (piece != null &&
            (piece.color == PieceColor.white) == _isWhiteTurn) {
          final from = Position(row, col);
          final legalMoves = getLegalMoves(from);
          if (legalMoves.isNotEmpty) moves.add(from);
        }
      }
    }
    return moves;
  }

  List<Position> _getPawnMoves(Position pos, PieceColor color) {
    final moves = <Position>[];
    final direction = color == PieceColor.white ? -1 : 1;
    final startRow = color == PieceColor.white ? 6 : 1;

    final oneForward = Position(pos.row + direction, pos.col);
    if (oneForward.isValid && _board[oneForward.row][oneForward.col] == null) {
      moves.add(oneForward);
      if (pos.row == startRow) {
        final twoForward = Position(pos.row + 2 * direction, pos.col);
        if (twoForward.isValid &&
            _board[twoForward.row][twoForward.col] == null) {
          moves.add(twoForward);
        }
      }
    }

    for (final dCol in [-1, 1]) {
      final capture = Position(pos.row + direction, pos.col + dCol);
      if (capture.isValid) {
        final target = _board[capture.row][capture.col];
        if (target != null && target.color != color) moves.add(capture);
        if (_enPassantTarget != null &&
            capture.row == _enPassantTarget!.row &&
            capture.col == _enPassantTarget!.col) {
          moves.add(capture);
        }
      }
    }

    return moves;
  }

  List<Position> _getKnightMoves(Position pos, PieceColor color) {
    final moves = <Position>[];
    const deltas = [
      [-2, -1], [-2, 1], [-1, -2], [-1, 2],
      [1, -2], [1, 2], [2, -1], [2, 1],
    ];
    for (final d in deltas) {
      final to = Position(pos.row + d[0], pos.col + d[1]);
      if (to.isValid) {
        final target = _board[to.row][to.col];
        if (target == null || target.color != color) moves.add(to);
      }
    }
    return moves;
  }

  List<Position> _getBishopMoves(Position pos, PieceColor color) {
    final moves = <Position>[];
    const deltas = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
    for (final d in deltas) {
      int row = pos.row + d[0];
      int col = pos.col + d[1];
      while (row >= 0 && row < 8 && col >= 0 && col < 8) {
        final target = _board[row][col];
        if (target == null) {
          moves.add(Position(row, col));
        } else {
          if (target.color != color) moves.add(Position(row, col));
          break;
        }
        row += d[0];
        col += d[1];
      }
    }
    return moves;
  }

  List<Position> _getRookMoves(Position pos, PieceColor color) {
    final moves = <Position>[];
    const deltas = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    for (final d in deltas) {
      int row = pos.row + d[0];
      int col = pos.col + d[1];
      while (row >= 0 && row < 8 && col >= 0 && col < 8) {
        final target = _board[row][col];
        if (target == null) {
          moves.add(Position(row, col));
        } else {
          if (target.color != color) moves.add(Position(row, col));
          break;
        }
        row += d[0];
        col += d[1];
      }
    }
    return moves;
  }

  List<Position> _getKingMoves(Position pos, PieceColor color) {
    final moves = <Position>[];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final to = Position(pos.row + dr, pos.col + dc);
        if (to.isValid) {
          final target = _board[to.row][to.col];
          if (target == null || target.color != color) moves.add(to);
        }
      }
    }

    if (color == PieceColor.white) {
      if (_whiteCanCastleKingside &&
          _board[7][5] == null && _board[7][6] == null &&
          !_isSquareAttacked(Position(7, 4), PieceColor.black) &&
          !_isSquareAttacked(Position(7, 5), PieceColor.black) &&
          !_isSquareAttacked(Position(7, 6), PieceColor.black)) {
        moves.add(Position(7, 6));
      }
      if (_whiteCanCastleQueenside &&
          _board[7][3] == null && _board[7][2] == null && _board[7][1] == null &&
          !_isSquareAttacked(Position(7, 4), PieceColor.black) &&
          !_isSquareAttacked(Position(7, 3), PieceColor.black) &&
          !_isSquareAttacked(Position(7, 2), PieceColor.black)) {
        moves.add(Position(7, 2));
      }
    } else {
      if (_blackCanCastleKingside &&
          _board[0][5] == null && _board[0][6] == null &&
          !_isSquareAttacked(Position(0, 4), PieceColor.white) &&
          !_isSquareAttacked(Position(0, 5), PieceColor.white) &&
          !_isSquareAttacked(Position(0, 6), PieceColor.white)) {
        moves.add(Position(0, 6));
      }
      if (_blackCanCastleQueenside &&
          _board[0][3] == null && _board[0][2] == null && _board[0][1] == null &&
          !_isSquareAttacked(Position(0, 4), PieceColor.white) &&
          !_isSquareAttacked(Position(0, 3), PieceColor.white) &&
          !_isSquareAttacked(Position(0, 2), PieceColor.white)) {
        moves.add(Position(0, 2));
      }
    }

    return moves;
  }

  bool _isSquareAttacked(Position pos, PieceColor attackerColor) {
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = _board[row][col];
        if (piece != null && piece.color == attackerColor) {
          final from = Position(row, col);
          List<Position> attacks;
          switch (piece.type) {
            case PieceType.pawn:
              final dir = attackerColor == PieceColor.white ? -1 : 1;
              attacks = [Position(row + dir, col - 1), Position(row + dir, col + 1)]
                  .where((p) => p.isValid).toList();
              break;
            case PieceType.knight:
              attacks = _getKnightMoves(from, attackerColor);
              break;
            case PieceType.bishop:
              attacks = _getBishopMoves(from, attackerColor);
              break;
            case PieceType.rook:
              attacks = _getRookMoves(from, attackerColor);
              break;
            case PieceType.queen:
              attacks = [..._getBishopMoves(from, attackerColor), ..._getRookMoves(from, attackerColor)];
              break;
            case PieceType.king:
              attacks = [];
              for (int dr = -1; dr <= 1; dr++) {
                for (int dc = -1; dc <= 1; dc++) {
                  if (dr == 0 && dc == 0) continue;
                  final p = Position(row + dr, col + dc);
                  if (p.isValid) attacks.add(p);
                }
              }
              break;
          }
          if (attacks.any((p) => p == pos)) return true;
        }
      }
    }
    return false;
  }

  bool _isInCheck(PieceColor color) {
    Position? kingPos;
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = _board[row][col];
        if (piece?.type == PieceType.king && piece?.color == color) {
          kingPos = Position(row, col);
          break;
        }
      }
    }
    if (kingPos == null) return false;
    return _isSquareAttacked(kingPos!,
        color == PieceColor.white ? PieceColor.black : PieceColor.white);
  }

  ChessMove? makeMove(Position from, Position to, {PieceType? promotion}) {
    final piece = _board[from.row][from.col];
    if (piece == null) return null;

    final legalMoves = getLegalMoves(from);
    if (!legalMoves.any((m) => m == to)) return null;

    final captured = _board[to.row][to.col];
    bool isCastling = false;
    bool isEnPassant = false;

    if (piece.type == PieceType.king && (to.col - from.col).abs() == 2) {
      isCastling = true;
      if (to.col > from.col) {
        _board[to.row][5] = _board[to.row][7];
        _board[to.row][7] = null;
      } else {
        _board[to.row][3] = _board[to.row][0];
        _board[to.row][0] = null;
      }
    }

    if (piece.type == PieceType.pawn &&
        to.col != from.col &&
        captured == null) {
      isEnPassant = true;
      final capturedPawnRow =
      piece.color == PieceColor.white ? to.row + 1 : to.row - 1;
      _board[capturedPawnRow][to.col] = null;
    }

    _enPassantTarget = null;
    if (piece.type == PieceType.pawn && (to.row - from.row).abs() == 2) {
      final epRow = (from.row + to.row) ~/ 2;
      _enPassantTarget = Position(epRow, from.col);
    }

    if (piece.type == PieceType.pawn && (to.row == 0 || to.row == 7)) {
      final promoType = promotion ?? PieceType.queen;
      _board[to.row][to.col] = ChessPiece(type: promoType, color: piece.color);
    } else {
      _board[to.row][to.col] = piece;
    }
    _board[from.row][from.col] = null;

    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) {
        _whiteCanCastleKingside = false;
        _whiteCanCastleQueenside = false;
      } else {
        _blackCanCastleKingside = false;
        _blackCanCastleQueenside = false;
      }
    }
    if (piece.type == PieceType.rook) {
      if (from.row == 7 && from.col == 0) _whiteCanCastleQueenside = false;
      if (from.row == 7 && from.col == 7) _whiteCanCastleKingside = false;
      if (from.row == 0 && from.col == 0) _blackCanCastleQueenside = false;
      if (from.row == 0 && from.col == 7) _blackCanCastleKingside = false;
    }

    _isWhiteTurn = !_isWhiteTurn;
    if (!_isWhiteTurn) _fullMoveNumber++;

    final newFen = _toFen();
    final inCheck =
    _isInCheck(_isWhiteTurn ? PieceColor.white : PieceColor.black);
    final inCheckmate = inCheck && _getAllLegalMoves().isEmpty;

    final move = ChessMove(
      from: from,
      to: to,
      piece: piece,
      captured: isEnPassant
          ? ChessPiece(
          type: PieceType.pawn,
          color: piece.color == PieceColor.white
              ? PieceColor.black
              : PieceColor.white)
          : captured,
      isCastling: isCastling,
      isEnPassant: isEnPassant,
      isCheck: inCheck,
      isCheckmate: inCheckmate,
      fenAfter: newFen,
    );

    _moves.add(move);
    return move;
  }

  List<ChessPiece?> _getCapturedPieces() {
    final captured = <ChessPiece?>[];
    const initialPieces = {
      PieceType.pawn: 8,
      PieceType.knight: 2,
      PieceType.bishop: 2,
      PieceType.rook: 2,
      PieceType.queen: 1,
    };

    for (final color in PieceColor.values) {
      final counts = <PieceType, int>{};
      for (int row = 0; row < 8; row++) {
        for (int col = 0; col < 8; col++) {
          final piece = _board[row][col];
          if (piece != null &&
              piece.color == color &&
              piece.type != PieceType.king) {
            counts[piece.type] = (counts[piece.type] ?? 0) + 1;
          }
        }
      }

      for (final type in initialPieces.keys) {
        final missing = (initialPieces[type] ?? 0) - (counts[type] ?? 0);
        for (int i = 0; i < missing; i++) {
          captured.add(ChessPiece(
            type: type,
            color: color == PieceColor.white
                ? PieceColor.black
                : PieceColor.white,
          ));
        }
      }
    }
    return captured;
  }
}