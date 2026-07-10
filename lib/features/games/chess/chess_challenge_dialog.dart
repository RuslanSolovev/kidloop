// features/games/chess/chess_challenge_dialog.dart
import 'package:flutter/material.dart';
import 'chess_api_service.dart';
import 'chess_board_screen.dart';

class ChessChallengeDialog extends StatelessWidget {
  final String opponentId;
  final String opponentName;
  final String? opponentAvatar;

  const ChessChallengeDialog({
    super.key,
    required this.opponentId,
    required this.opponentName,
    this.opponentAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.orange.shade100,
              backgroundImage: opponentAvatar != null ? NetworkImage(opponentAvatar!) : null,
              child: opponentAvatar == null
                  ? Text(opponentName[0].toUpperCase(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 28))
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Вызвать на шахматную дуэль?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              opponentName,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final gameId = await ChessApiService.createGame(
                        opponentId: opponentId,
                        opponentName: opponentName,
                      );
                      if (gameId != null && context.mounted) {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChessBoardScreen(gameId: gameId)),
                        );
                      }
                    },
                    icon: const Icon(Icons.sports_esports_rounded, size: 20),
                    label: const Text('Играть!'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}