import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/message.dart';

class TicTacToeWidget extends StatefulWidget {
  final String roomCode;
  final Message message;

  const TicTacToeWidget({super.key, required this.roomCode, required this.message});

  @override
  State<TicTacToeWidget> createState() => _TicTacToeWidgetState();
}

class _TicTacToeWidgetState extends State<TicTacToeWidget> {
  // Format: !xox|playerX_id|playerO_id|board_csv|turn_id|status

  List<String> _parseState(String text) {
    final parts = text.split('|');
    if (parts.length < 6) {
      return ['!xox', '', '', ',,,,,,,,', '', 'waiting'];
    }
    return parts;
  }

  String _serializeState(String playerX, String playerO, List<String> board, String turn, String status) {
    return '!xox|$playerX|$playerO|${board.join(',')}|$turn|$status';
  }

  Future<void> _makeMove(int index, List<String> parts, String myId) async {
    String playerX = parts[1];
    String playerO = parts[2];
    List<String> board = parts[3].split(',');
    String turnId = parts[4];
    String status = parts[5];

    if (board.length != 9) board = List.filled(9, '');

    // Join as Player O if empty and not Player X
    if (playerO == '' && playerX != myId) {
      playerO = myId;
      if (turnId == '') turnId = playerX; // X starts when O joins
      status = 'playing';
      
      final newState = _serializeState(playerX, playerO, board, turnId, status);
      await context.read<ChatProvider>().editMessage(widget.message.id, newState);
      return;
    }

    if (status != 'playing') return;
    if (turnId != myId) return; // Not my turn
    if (board[index] != '') return; // Cell taken

    board[index] = myId;
    final nextTurn = (myId == playerX) ? playerO : playerX;
    
    String winner = _checkWinner(board);
    if (winner != '') {
      status = 'ended';
    } else if (!board.contains('')) {
      status = 'draw';
    } else {
      status = 'playing';
    }

    final newState = _serializeState(playerX, playerO, board, status == 'playing' ? nextTurn : '', status);
    await context.read<ChatProvider>().editMessage(widget.message.id, newState);
  }

  String _checkWinner(List<String> board) {
    List<List<int>> combos = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6]
    ];
    for (var combo in combos) {
      if (board[combo[0]] != '' &&
          board[combo[0]] == board[combo[1]] &&
          board[combo[1]] == board[combo[2]]) {
        return board[combo[0]];
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final myId = chatProvider.currentUserId;
    if (myId == null) return const SizedBox.shrink();

    final parts = _parseState(widget.message.text);
    final playerX = parts[1];
    final playerO = parts[2];
    final boardStr = parts[3];
    List<String> board = boardStr.split(',');
    if (board.length != 9) board = List.filled(9, '');
    final turnId = parts[4];
    final status = parts[5];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("❌ ", style: TextStyle(fontSize: 16)),
              Text(
                playerX == myId ? "Sen" : "Oyuncu 1",
                style: TextStyle(
                  color: playerX == myId ? Colors.greenAccent : Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text("  vs  ", style: TextStyle(color: Colors.white54)),
              Text(
                playerO == '' ? "Bekleniyor..." : (playerO == myId ? "Sen" : "Oyuncu 2"),
                style: TextStyle(
                  color: playerO == myId ? Colors.greenAccent : Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(" ⭕", style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          if (status == 'playing')
            Text(
              turnId == myId ? "Sıra Sende!" : "Rakip Bekleniyor...",
              style: TextStyle(
                color: turnId == myId ? Colors.amber : Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (status == 'ended')
            Text(
              "🏆 KAZANAN: ${turnId == myId ? 'Rakip' : 'Sen'}",
              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          if (status == 'draw')
            const Text("🤝 BERABERE!", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16)),
          if (status == 'waiting')
            const Text("Savaşa katılmak için tıkla!", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              String cellValue = '';
              if (board[index] == playerX) cellValue = '❌';
              if (board[index] == playerO) cellValue = '⭕';

              return GestureDetector(
                onTap: () => _makeMove(index, parts, myId),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: Text(
                      cellValue,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            },
          ),
          if (status == 'waiting' && playerO == '' && playerX != myId)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: () => _makeMove(0, parts, myId), // 0 doesn't matter for joining
                icon: const Icon(Icons.sports_esports),
                label: const Text("Oyuna Katıl"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF159D87),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
