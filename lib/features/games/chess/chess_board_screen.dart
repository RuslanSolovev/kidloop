// features/games/chess/chess_board_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chess_models.dart';
import 'chess_logic.dart';
import 'chess_widgets.dart';
import 'chess_api_service.dart';

class ChessBoardScreen extends StatefulWidget {
  final String gameId;
  final bool hasTimer;

  const ChessBoardScreen({
    super.key,
    required this.gameId,
    this.hasTimer = false,
  });

  @override
  State<ChessBoardScreen> createState() => _ChessBoardScreenState();
}

class _ChessBoardScreenState extends State<ChessBoardScreen>
    with TickerProviderStateMixin {
  final ChessLogic _logic = ChessLogic();
  ChessGameModel? _game;
  Position? _selectedPosition;
  List<Position> _legalMoves = [];
  Position? _lastMoveFrom;
  Position? _lastMoveTo;
  String? _currentUserId;
  bool _isMyTurn = false;
  bool _isFlipped = false;
  Timer? _pollTimer;
  int _myTimeLeft = 600000;
  int _opponentTimeLeft = 600000;
  bool _gameOver = false;
  bool _timeWarning = false;

  late AnimationController _shakeController;
  late AnimationController _timeWarningController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _timeWarningAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
    _timeWarningController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _timeWarningAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _timeWarningController, curve: Curves.easeInOut));
    _timeWarningController.repeat(reverse: true);
    _initGame();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _shakeController.dispose();
    _timeWarningController.dispose();
    super.dispose();
  }

  Future<void> _initGame() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');

    final game = await ChessApiService.getGame(widget.gameId);
    if (game != null && mounted) {
      setState(() {
        _game = game;
        _logic.loadFromFen(game.fen);
        _isFlipped = _currentUserId == game.whitePlayerId;
        _isMyTurn = (_logic.isWhiteTurn && _currentUserId == game.whitePlayerId) ||
            (!_logic.isWhiteTurn && _currentUserId == game.blackPlayerId);
        if (widget.hasTimer) {
          _myTimeLeft = _currentUserId == game.whitePlayerId ? game.whiteTimeLeft : game.blackTimeLeft;
          _opponentTimeLeft = _currentUserId == game.whitePlayerId ? game.blackTimeLeft : game.whiteTimeLeft;
        }
      });
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_gameOver || !mounted) return;
      final game = await ChessApiService.getGame(widget.gameId);
      if (game != null && mounted) {
        setState(() {
          final oldFen = _game?.fen ?? '';
          _game = game;
          if (game.fen != oldFen) {
            _logic.loadFromFen(game.fen);
          }
          _isMyTurn = (_logic.isWhiteTurn && _currentUserId == game.whitePlayerId) ||
              (!_logic.isWhiteTurn && _currentUserId == game.blackPlayerId);
          if (widget.hasTimer) {
            _myTimeLeft = _currentUserId == game.whitePlayerId ? game.whiteTimeLeft : game.blackTimeLeft;
            _opponentTimeLeft = _currentUserId == game.whitePlayerId ? game.blackTimeLeft : game.whiteTimeLeft;
            _timeWarning = _isMyTurn && _myTimeLeft <= 30000 && _myTimeLeft > 0;
          }
          if (game.moves.isNotEmpty) {
            final lastMove = game.moves.last;
            _lastMoveFrom = lastMove.from;
            _lastMoveTo = lastMove.to;
          }
          if (game.status == GameStatus.completed) {
            _gameOver = true;
            _pollTimer?.cancel();
            _showGameResult(game);
          }
        });
      }
    });
  }

  void _onSquareTap(Position pos) {
    if (!_isMyTurn || _game?.status != GameStatus.active || _gameOver) return;
    if (_selectedPosition == null) {
      final piece = _logic.board[pos.row][pos.col];
      if (piece != null && ((piece.color == PieceColor.white) == (_currentUserId == _game?.whitePlayerId))) {
        setState(() { _selectedPosition = pos; _legalMoves = _logic.getLegalMoves(pos); });
      }
    } else {
      if (_legalMoves.contains(pos)) {
        final from = _selectedPosition!;
        final move = _logic.makeMove(from, pos);
        if (move != null) {
          setState(() {
            _selectedPosition = null;
            _legalMoves = [];
            _lastMoveFrom = move.from;
            _lastMoveTo = move.to;
            _isMyTurn = false;
          });
          _makeMoveOnServer(from, pos);
          if (_logic.isCheckmate) {
            _gameOver = true;
            _pollTimer?.cancel();
            ChessApiService.resign(widget.gameId, reason: 'checkmate');
            _showGameOver('Мат! Вы победили! 🎉');
          }
        }
      } else {
        final piece = _logic.board[pos.row][pos.col];
        if (piece != null && ((piece.color == PieceColor.white) == (_currentUserId == _game?.whitePlayerId))) {
          setState(() { _selectedPosition = pos; _legalMoves = _logic.getLegalMoves(pos); });
        } else {
          setState(() { _selectedPosition = null; _legalMoves = []; });
        }
      }
    }
  }

  Future<void> _makeMoveOnServer(Position from, Position to) async {
    final whiteTime = _currentUserId == _game?.whitePlayerId ? _myTimeLeft : _opponentTimeLeft;
    final blackTime = _currentUserId == _game?.blackPlayerId ? _myTimeLeft : _opponentTimeLeft;

    await ChessApiService.makeMove(
      gameId: widget.gameId, from: from.notation, to: to.notation,
      fen: _logic.currentFen, whiteTimeLeft: whiteTime, blackTimeLeft: blackTime,
    );
  }

  void _showGameResult(ChessGameModel game) {
    final isWhite = _currentUserId == game.whitePlayerId;
    final result = game.result;
    final winnerId = game.winnerId;

    print('🔍 Game Over - result: $result, winnerId: $winnerId, isWhite: $isWhite, myId: $_currentUserId');

    // Если есть winner_id, определяем по нему
    if (winnerId != null && winnerId.isNotEmpty) {
      final iWon = winnerId == _currentUserId;
      final message = iWon ? 'Вы победили! 🎉' : 'Вы проиграли 😢';
      _showGameOver(message);
      return;
    }

    // Иначе определяем по result
    bool iWon;
    bool isDraw;

    switch (result) {
      case GameResult.whiteWin:
        iWon = isWhite;
        isDraw = false;
        break;
      case GameResult.blackWin:
        iWon = !isWhite;
        isDraw = false;
        break;
      case GameResult.whiteWinTimeout:
        iWon = isWhite;
        isDraw = false;
        break;
      case GameResult.blackWinTimeout:
        iWon = !isWhite;
        isDraw = false;
        break;
      case GameResult.draw:
        iWon = false;
        isDraw = true;
        break;
      case GameResult.resign:
      case GameResult.timeout:
      case null:
      default:
      // 🔥 Если result == null или неизвестный — проверяем по цвету и очереди
      // Если игра завершена и мой ход — я проиграл (таймаут)
      // Если игра завершена и не мой ход — я выиграл
        if (game.status == GameStatus.completed) {
          iWon = !_isMyTurn; // Если не мой ход — я выиграл
          isDraw = false;
        } else {
          iWon = false;
          isDraw = true;
        }
    }

    final message = isDraw ? 'Ничья! 🤝' : (iWon ? 'Вы победили! 🎉' : 'Вы проиграли 😢');
    _showGameOver(message);
  }

  void _showGameOver(String message) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(message, textAlign: TextAlign.center),
        content: const Text('Игра завершена'),
        actions: [TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('Выйти'))],
      ),
    );
  }

  Future<void> _resign() async {
    if (_gameOver) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Сдаться?'), content: const Text('Вы уверены?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Сдаться')),
        ],
      ),
    );
    if (confirm == true) {
      _gameOver = true; _pollTimer?.cancel();
      await ChessApiService.resign(widget.gameId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final backgroundColor = isDark ? const Color(0xFF0A0A1A) : const Color(0xFFF8F9FA);

    if (_game == null) return Scaffold(backgroundColor: backgroundColor, body: const Center(child: CircularProgressIndicator(color: Colors.orange)));

    final opponentName = _currentUserId == _game!.whitePlayerId ? _game!.blackPlayerName : _game!.whitePlayerName;
    final myName = _currentUserId == _game!.whitePlayerId ? _game!.whitePlayerName : _game!.blackPlayerName;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Column(children: [
          Text('♟ Шахматы', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          Text('vs $opponentName', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
        centerTitle: true,
        actions: [if (!_gameOver) IconButton(icon: const Icon(Icons.flag_rounded, color: Colors.red), onPressed: _resign, tooltip: 'Сдаться')],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (widget.hasTimer)
                ChessTimerWidget(millisecondsLeft: _opponentTimeLeft, isActive: !_isMyTurn && !_gameOver, playerName: opponentName),
              if (widget.hasTimer) const SizedBox(height: 8),
              CapturedPiecesWidget(pieces: _logic.capturedPieces, isMine: false),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: _gameOver
                      ? Opacity(opacity: 0.5, child: ChessBoardWidget(board: _logic.board, legalMoves: [], lastMoveFrom: _lastMoveFrom, lastMoveTo: _lastMoveTo, isFlipped: _isFlipped, isWhiteTurn: false, isCheck: false, onSquareTap: (_) {}))
                      : ChessBoardWidget(board: _logic.board, selectedPosition: _selectedPosition, legalMoves: _legalMoves, lastMoveFrom: _lastMoveFrom, lastMoveTo: _lastMoveTo, isFlipped: _isFlipped, isWhiteTurn: _logic.isWhiteTurn, isCheck: _logic.isCheck, onSquareTap: _onSquareTap),
                ),
              ),
              const SizedBox(height: 8),
              CapturedPiecesWidget(pieces: _logic.capturedPieces, isMine: true),
              if (widget.hasTimer) ...[
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _timeWarningAnimation,
                  builder: (context, child) => Transform.scale(scale: _timeWarning && _isMyTurn ? _timeWarningAnimation.value : 1.0, child: child),
                  child: ChessTimerWidget(millisecondsLeft: _myTimeLeft, isActive: _isMyTurn && !_gameOver, playerName: myName, isTop: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}