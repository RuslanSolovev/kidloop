// features/games/chess/chess_models.dart
enum PieceType { king, queen, rook, bishop, knight, pawn }

enum PieceColor { white, black }

enum GameStatus { waiting, active, completed, cancelled }

enum GameResult {
  whiteWin,
  blackWin,
  draw,
  resign,
  timeout,
  abandoned,
  whiteWinTimeout,
  blackWinTimeout,
}

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  final String id;

  ChessPiece({required this.type, required this.color})
      : id = '${color.name}_${type.name}_${DateTime.now().microsecondsSinceEpoch}';

  String get symbol {
    const symbols = {
      PieceType.king: '♚',
      PieceType.queen: '♛',
      PieceType.rook: '♜',
      PieceType.bishop: '♝',
      PieceType.knight: '♞',
      PieceType.pawn: '♟',
    };
    final s = symbols[type] ?? '?';
    return color == PieceColor.white ? s : s;
  }

  String get fenSymbol {
    const symbols = {
      PieceType.king: 'k',
      PieceType.queen: 'q',
      PieceType.rook: 'r',
      PieceType.bishop: 'b',
      PieceType.knight: 'n',
      PieceType.pawn: 'p',
    };
    final s = symbols[type] ?? '?';
    return color == PieceColor.white ? s.toUpperCase() : s;
  }

  ChessPiece copy() => ChessPiece(type: type, color: color);
}

class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  String get notation {
    const files = 'abcdefgh';
    return '${files[col]}${8 - row}';
  }

  static Position? fromNotation(String notation) {
    if (notation.length != 2) return null;
    const files = 'abcdefgh';
    final file = notation[0].toLowerCase();
    final rank = int.tryParse(notation[1]);
    if (rank == null || rank < 1 || rank > 8) return null;
    final col = files.indexOf(file);
    if (col == -1) return null;
    return Position(8 - rank, col);
  }

  bool get isValid => row >= 0 && row < 8 && col >= 0 && col < 8;

  @override
  bool operator ==(Object other) =>
      other is Position && row == other.row && col == other.col;

  @override
  int get hashCode => row * 8 + col;

  @override
  String toString() => notation;
}

class ChessMove {
  final Position from;
  final Position to;
  final ChessPiece piece;
  final ChessPiece? captured;
  final ChessPiece? promotion;
  final bool isCastling;
  final bool isEnPassant;
  final bool isCheck;
  final bool isCheckmate;
  final String fenAfter;

  ChessMove({
    required this.from,
    required this.to,
    required this.piece,
    this.captured,
    this.promotion,
    this.isCastling = false,
    this.isEnPassant = false,
    this.isCheck = false,
    this.isCheckmate = false,
    required this.fenAfter,
  });

  String get notation {
    if (isCastling) {
      return to.col > from.col ? 'O-O' : 'O-O-O';
    }
    final pieceSymbol = piece.type == PieceType.pawn ? '' : piece.fenSymbol.toUpperCase();
    final captureSymbol = captured != null ? 'x' : '-';
    final promo = promotion != null ? '=${promotion!.fenSymbol.toUpperCase()}' : '';
    final check = isCheckmate ? '#' : (isCheck ? '+' : '');
    return '$pieceSymbol${from.notation}$captureSymbol${to.notation}$promo$check';
  }
}

class ChessGameModel {
  final String gameId;
  final String whitePlayerId;
  final String blackPlayerId;
  final String whitePlayerName;
  final String blackPlayerName;
  final GameStatus status;
  final String fen;
  final GameResult? result;
  final String? winnerId;
  final int timeControl;
  final int increment;
  final int whiteTimeLeft;
  final int blackTimeLeft;
  final DateTime createdAt;
  final DateTime? lastMoveAt;
  final List<ChessMove> moves;
  final DateTime? completedAt;

  ChessGameModel({
    required this.gameId,
    required this.whitePlayerId,
    required this.blackPlayerId,
    this.whitePlayerName = '',
    this.blackPlayerName = '',
    this.status = GameStatus.waiting,
    this.fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    this.result,
    this.winnerId,
    this.timeControl = 600,
    this.increment = 0,
    this.whiteTimeLeft = 600000,
    this.blackTimeLeft = 600000,
    required this.createdAt,
    this.lastMoveAt,
    this.moves = const [],
    this.completedAt,
  });

  bool get isWhiteTurn {
    final parts = fen.split(' ');
    return parts.length > 1 && parts[1] == 'w';
  }

  ChessGameModel copyWith({
    String? gameId,
    String? whitePlayerId,
    String? blackPlayerId,
    String? whitePlayerName,
    String? blackPlayerName,
    GameStatus? status,
    String? fen,
    GameResult? result,
    String? winnerId,
    int? timeControl,
    int? increment,
    int? whiteTimeLeft,
    int? blackTimeLeft,
    DateTime? createdAt,
    DateTime? lastMoveAt,
    List<ChessMove>? moves,
  }) {
    return ChessGameModel(
      gameId: gameId ?? this.gameId,
      whitePlayerId: whitePlayerId ?? this.whitePlayerId,
      blackPlayerId: blackPlayerId ?? this.blackPlayerId,
      whitePlayerName: whitePlayerName ?? this.whitePlayerName,
      blackPlayerName: blackPlayerName ?? this.blackPlayerName,
      status: status ?? this.status,
      fen: fen ?? this.fen,
      result: result ?? this.result,
      winnerId: winnerId ?? this.winnerId,
      timeControl: timeControl ?? this.timeControl,
      increment: increment ?? this.increment,
      whiteTimeLeft: whiteTimeLeft ?? this.whiteTimeLeft,
      blackTimeLeft: blackTimeLeft ?? this.blackTimeLeft,
      createdAt: createdAt ?? this.createdAt,
      lastMoveAt: lastMoveAt ?? this.lastMoveAt,
      moves: moves ?? this.moves,
    );
  }
}

class ChessChallenge {
  final String challengeId;
  final String fromUserId;
  final String toUserId;
  final String fromUserName;
  final String toUserName;
  final String status;
  final int timeControl;
  final DateTime createdAt;
  final DateTime expiresAt;

  ChessChallenge({
    required this.challengeId,
    required this.fromUserId,
    required this.toUserId,
    this.fromUserName = '',
    this.toUserName = '',
    this.status = 'pending',
    this.timeControl = 600,
    required this.createdAt,
    required this.expiresAt,
  });
}

class ChessRating {
  final String userId;
  final String userName;
  final int rating;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final int winStreak;
  final int bestRating;

  ChessRating({
    required this.userId,
    this.userName = '',
    this.rating = 1200,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.winStreak = 0,
    this.bestRating = 1200,
  });

  double get winRate => gamesPlayed > 0 ? wins / gamesPlayed * 100 : 0;
}