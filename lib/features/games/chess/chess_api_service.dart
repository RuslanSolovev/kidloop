// features/games/chess/chess_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'chess_models.dart';

class ChessApiService {
  static const String _apiUrl = 'https://functions.yandexcloud.net/d4edmoonsukf22mq48uo';

  static Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  static Future<String?> _getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  static Future<String?> createGame({
    required String opponentId,
    required String opponentName,
    int timeControl = 600,
    int increment = 0,
  }) async {
    final userId = await _getUserId();
    final userName = await _getUserName();
    if (userId == null) return null;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "create-chess-game",
          "white_id": userId,
          "white_name": userName,
          "black_id": opponentId,
          "black_name": opponentName,
          "time_control": timeControl,
          "increment": increment,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) return data['game_id'];
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> joinQueue({int timeControl = 600}) async {
    final userId = await _getUserId();
    final userName = await _getUserName();
    if (userId == null) return null;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "join-chess-queue",
          "user_id": userId,
          "user_name": userName,
          "time_control": timeControl,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> leaveQueue() async {
    final userId = await _getUserId();
    if (userId == null) return false;

    try {
      await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "leave-chess-queue", "user_id": userId}),
      ).timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> checkQueue() async {
    final userId = await _getUserId();
    if (userId == null) return false;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "check-chess-queue", "user_id": userId}),
      ).timeout(const Duration(seconds: 5));
      final data = jsonDecode(response.body);
      return data['in_queue'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> makeMove({
    required String gameId,
    required String from,
    required String to,
    String? promotion,
    String? fen,
    int? whiteTimeLeft,
    int? blackTimeLeft,
  }) async {
    final userId = await _getUserId();
    if (userId == null) return false;

    try {
      final body = <String, dynamic>{
        "action": "make-chess-move",
        "game_id": gameId,
        "player_id": userId,
        "from": from,
        "to": to,
        "promotion": promotion,
        "fen": fen,
        "white_time_left": whiteTimeLeft,
        "black_time_left": blackTimeLeft,
      };

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      return data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<ChessGameModel?> getGame(String gameId) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-chess-game", "game_id": gameId}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        return ChessGameModel(
          gameId: data['game_id'] ?? '',
          whitePlayerId: data['white_id'] ?? '',
          blackPlayerId: data['black_id'] ?? '',
          whitePlayerName: data['white_name'] ?? '',
          blackPlayerName: data['black_name'] ?? '',
          status: _parseStatus(data['status']),

          fen: data['fen'] ?? '',
          timeControl: data['time_control'] ?? 0,
          increment: data['increment'] ?? 0,
          whiteTimeLeft: data['white_time_left'] ?? 0,
          blackTimeLeft: data['black_time_left'] ?? 0,
          createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
          lastMoveAt: DateTime.tryParse(data['last_move_at'] ?? ''),
          result: _parseResult(data['result']),
          winnerId: data['winner_id'], // 🔥 Убедись, что это поле есть
        );
      }
    } catch (_) {}
    return null;
  }

  static Future<List<ChessGameModel>> getActiveGames() async {
    final userId = await _getUserId();
    if (userId == null) return [];

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-active-chess-games", "user_id": userId}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        return (data['games'] as List).map((g) => ChessGameModel(
          gameId: g['game_id'] ?? '',
          whitePlayerId: g['white_id'] ?? '',
          blackPlayerId: g['black_id'] ?? '',
          whitePlayerName: g['white_name'] ?? '',
          blackPlayerName: g['black_name'] ?? '',
          status: _parseStatus(g['status']),
          fen: g['fen'] ?? '',
          timeControl: g['time_control'] ?? 0,
          createdAt: DateTime.tryParse(g['created_at'] ?? '') ?? DateTime.now(),
        )).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> sendChallenge({
    required String toUserId,
    required String toUserName,
    int timeControl = 0,
  }) async {
    final userId = await _getUserId();
    final userName = await _getUserName();
    if (userId == null) return false;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "send-chess-challenge",
          "from_id": userId,
          "from_name": userName,
          "to_id": toUserId,
          "to_name": toUserName,
          "time_control": timeControl,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      return data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<ChessChallenge>> getChallenges() async {
    final userId = await _getUserId();
    if (userId == null) return [];

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-chess-challenges", "user_id": userId}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        return (data['challenges'] as List).map((c) => ChessChallenge(
          challengeId: c['challenge_id'] ?? '',
          fromUserId: c['from_id'] ?? '',
          toUserId: c['to_id'] ?? '',
          fromUserName: c['from_name'] ?? '',
          toUserName: c['to_name'] ?? '',
          status: c['status'] ?? 'pending',
          timeControl: c['time_control'] ?? 0,
          createdAt: DateTime.tryParse(c['created_at'] ?? '') ?? DateTime.now(),
          expiresAt: DateTime.tryParse(c['expires_at'] ?? '') ?? DateTime.now(),
        )).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<String?> respondChallenge(String challengeId, bool accept) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "respond-chess-challenge",
          "challenge_id": challengeId,
          "response": accept ? "accepted" : "declined",
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true && accept) return data['game_id'];
    } catch (_) {}
    return null;
  }

  static Future<ChessRating?> getRating(String userId) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-chess-rating", "user_id": userId}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        return ChessRating(
          userId: userId,
          userName: data['user_name'] ?? '',
          rating: data['rating'] ?? 1200,
          gamesPlayed: data['games_played'] ?? 0,
          wins: data['wins'] ?? 0,
          losses: data['losses'] ?? 0,
          draws: data['draws'] ?? 0,
          winStreak: data['win_streak'] ?? 0,
          bestRating: data['best_rating'] ?? 1200,
        );
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> resign(String gameId, {String reason = 'resign'}) async {
    final userId = await _getUserId();
    if (userId == null) return false;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "action": "resign-chess-game",
          "game_id": gameId,
          "player_id": userId,
          "reason": reason,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      return data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // В класс ChessApiService добавить:
  static Future<List<ChessGameModel>> getGameHistory(String userId) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"action": "get-chess-history", "user_id": userId, "limit": 50}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        return (data['games'] as List).map((g) => ChessGameModel(
          gameId: g['game_id'] ?? '',
          whitePlayerId: g['white_id'] ?? '',
          blackPlayerId: g['black_id'] ?? '',
          whitePlayerName: g['white_name'] ?? '',
          blackPlayerName: g['black_name'] ?? '',
          status: _parseStatus(g['status']),
          result: _parseResult(g['result']),
          createdAt: DateTime.tryParse(g['created_at'] ?? '') ?? DateTime.now(),
          completedAt: DateTime.tryParse(g['completed_at'] ?? ''),
        )).toList();
      }
    } catch (_) {}
    return [];
  }

  static GameResult _parseResult(String? result) {
    if (result == null || result.isEmpty) return GameResult.draw; // На всякий случай
    switch (result) {
      case 'white_win': return GameResult.whiteWin;
      case 'black_win': return GameResult.blackWin;
      case 'draw': return GameResult.draw;
      case 'resign': return GameResult.resign;
      case 'timeout': return GameResult.timeout;
      case 'white_win_timeout': return GameResult.whiteWinTimeout;
      case 'black_win_timeout': return GameResult.blackWinTimeout;
      default: return GameResult.draw;
    }
  }

  static GameStatus _parseStatus(String? status) {
    switch (status) {
      case 'waiting': return GameStatus.waiting;
      case 'active': return GameStatus.active;
      case 'completed': return GameStatus.completed;
      case 'cancelled': return GameStatus.cancelled;
      default: return GameStatus.waiting;
    }
  }
}